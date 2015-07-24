#include "cctk.h"
#include <sys/types.h>
#include "schedule/Schedule.h"
#include <iostream>
#include <map>
#include <vector>
#include <set>
#include <algorithm>

// TODO:
// (1) Disallow multiple writes to the same variable
// (2) Maximum of one input read version and one output write version of a variable per group/function
// (3) Correctly calculate the one read/write version in group discovery

inline char lc(char c) {
  if(c >= 'A' && c <= 'Z')
    return c + 'a'-'A';
  else
    return c;
}

struct read_write_info {
  t_sched_group *group;
  bool finished, processing, is_group;

  std::set<std::string> boundary_read;
  std::set<std::string> boundary_write;
  std::set<std::string> interior_read;
  std::set<std::string> interior_write;

  std::map<int,std::set<int> > after;
  read_write_info() : group(0), finished(false), processing(false), is_group(false) {}
};

extern "C"
int CCTKi_rdwr_assign_after(std::map<std::string,read_write_info> *rdwr_map,int item,int size,int *thisorders,t_sched_group *group) {
  std::string name = group->scheditems[item].name;
  read_write_info *rdwr = &(*rdwr_map)[name];
  std::cout << "after::(" << name << ") -> ???" << std::endl;
  auto src=rdwr->after[item];
  for(auto i=src.begin();i != src.end();++i) {
    if(*i >= size) {
      std::cout << "assign_after: *i=" << *i << " size=" << size << std::endl;
      continue;
    }
    if(*i == item)
      continue;
    if(thisorders[*i] == -1) {
      std::cout << "assign_after order error" << std::endl;
      return -1; // schedule order error
    }
    //thisorders[*i] = 1;
    std::cout << "after::(" << name << ") -> " << *i << std::endl;
  }
  return 0;
}

extern "C"
void CCTKi_rdwr_free(std::map<std::string,read_write_info> *rdwr_map) {
  delete rdwr_map;
}

extern "C"
void CCTKi_rdwr_alloc(std::map<std::string,read_write_info> **rdwr_map) {
  *rdwr_map = new std::map<std::string,read_write_info>();
}

int indents = 0;

extern "C"
void CCTKi_rdwr_group_discover1(std::map<std::string,read_write_info> *rdwr_map, const char *name) {

  read_write_info *rdwr = &(*rdwr_map)[name];
  if(rdwr->processing || rdwr->finished)
    return;

  rdwr->processing = true;

  t_sched_group *group = rdwr->group;
  if(group == 0) {
    std::cout << "group is null for " << name << std::endl;
    return;
  }

  const int n = group->n_scheditems;
  for(int i=0;i<indents;i++) std::cout << "  ";
  std::cout << "group_discover (" << name << ")" << std::endl;
  indents++;
  for(int i=0;i<n;i++) {
    std::string subname = group->scheditems[i].name;
    read_write_info *sub_rdwr = &(*rdwr_map)[subname];
    for(int i=0;i<indents;i++) std::cout << "  ";
    std::cout << "check: (" << subname << ")" << std::endl;
    if(sub_rdwr->processing) {
      for(int i=0;i<indents;i++) std::cout << "  ";
      std::cout << "CYCLE!" << std::endl;
    }
    if(true) {//sub_rdwr->is_group) {
      if(sub_rdwr->finished) {
        ;
      } else if(sub_rdwr->group == 0) {
        for(int i=0;i<indents;i++) std::cout << "  ";
        std::cout << "  Can't discover (" << subname << ")" << std::endl;
      } else {
        CCTKi_rdwr_group_discover1(rdwr_map,subname.c_str());
      }
    }
    // copy dependency info
    for(auto j=sub_rdwr->boundary_read.begin(); j != sub_rdwr->boundary_read.end(); ++j)
      rdwr->boundary_read.insert(*j);
    for(auto j=sub_rdwr->boundary_write.begin(); j != sub_rdwr->boundary_write.end(); ++j)
      rdwr->boundary_write.insert(*j);
    for(auto j=sub_rdwr->interior_read.begin(); j != sub_rdwr->interior_read.end(); ++j)
      rdwr->interior_read.insert(*j);
    for(auto j=sub_rdwr->interior_write.begin(); j != sub_rdwr->interior_write.end(); ++j)
      rdwr->interior_write.insert(*j);
    sub_rdwr->processing = false;
    sub_rdwr->finished = true;
  }
  indents--;
  for(int i=0;i<indents;i++) std::cout << "  ";
  std::cout << "group_discover done (" << name << ")" << std::endl;
}

extern "C"
void CCTKi_rdwr_group_discover(std::map<std::string,read_write_info> *rdwr_map,t_sched_group *group) {
  //read_write_info *rdwr = &(*rdwr_map)[group->name];
  const int n = group->n_scheditems;
  for(int i=0;i<n;i++) {
    read_write_info *rdwr = &(*rdwr_map)[group->scheditems[i].name];
    if(rdwr->is_group) {
      if(!rdwr->finished) {
        //std::cout << "Group: " << group->name << " :> " << group->scheditems[i].name << std::endl;
        CCTKi_rdwr_group_discover1( rdwr_map, group->scheditems[i].name );
      }
    }
  }
}

extern "C"
void CCTKi_rdwr_discover(std::map<std::string,read_write_info> *rdwr_map,t_sched_group *group) {
  read_write_info *rdwr = &(*rdwr_map)[group->name];
  const int n = group->n_scheditems;
  rdwr->group = group;
  for(int i=0;i<n;i++) {
    t_attribute *attr = group->scheditems[i].attributes;
    std::string sub_name = group->scheditems[i].name;
    read_write_info *sub_rdwr = &(*rdwr_map)[sub_name];
    if(attr->type == sched_group) {
      (*rdwr_map)[group->scheditems[i].name].is_group=true;
      continue;
    }
    std::cout << "DISCOVER::(" << sub_name << ") from " << group->name << " ";
    const int nw = attr->FunctionData.n_WritesClauses;
    for(int j=0;j<nw;j++) {
      const char *s = attr->FunctionData.WritesClauses[j];
      std::string info[2];
      int info_ptr = 0;
      // Parse the string
      for(int k=0;s[k] != 0;k++) {
        if(s[k]=='(')
          info_ptr = 1;
        else if(s[k]==')')
          ;
        else
          info[info_ptr] += lc(s[k]);
      }
      if(info[1] == "interior") {
        sub_rdwr->interior_write.insert(info[0]);
      } else if(info[1] == "boundary") {
        sub_rdwr->boundary_write.insert(info[0]);
      } else {
        sub_rdwr->interior_write.insert(info[0]);
        sub_rdwr->boundary_write.insert(info[0]);
      }
    }
    const int nr = attr->FunctionData.n_ReadsClauses;
    for(int j=0;j<nr;j++) {
      const char *s = attr->FunctionData.ReadsClauses[j];
      std::string info[2];
      int info_ptr = 0;
      // Parse the string
      for(int k=0;s[k] != 0;k++) {
        if(s[k]=='(')
          info_ptr = 1;
        else if(s[k]==')')
          ;
        else
          info[info_ptr] += lc(s[k]);
      }
      if(info[1] == "interior") {
        sub_rdwr->interior_read.insert(info[0]);
      } else if(info[1] == "boundary") {
        sub_rdwr->boundary_read.insert(info[0]);
      } else {
        sub_rdwr->interior_read.insert(info[0]);
        sub_rdwr->boundary_read.insert(info[0]);
      }
    }
    sub_rdwr->finished = true;
    std::cout << std::endl;
  }
}

extern "C"
void CCTKi_rdwr_after_discover(std::map<std::string,read_write_info> *rdwr_map,t_sched_group *group) {
  //read_write_info *rdwr = &(*rdwr_map)[group->name];
  const int n = group->n_scheditems;

  std::map<std::string,std::set<int> > deps;
  for(int i=0;i<n;i++) {
    std::string sub_name = group->scheditems[i].name;
    read_write_info *sub_rdwr = &(*rdwr_map)[sub_name];

    for(auto j=sub_rdwr->boundary_write.begin(); j != sub_rdwr->boundary_write.end(); ++j) {
      deps[*j].insert(i);
    }
  }
  for(int i=0;i<n;i++) {
    std::string sub_name = group->scheditems[i].name;
    read_write_info *sub_rdwr = &(*rdwr_map)[sub_name];

    for(auto j=sub_rdwr->boundary_read.begin(); j != sub_rdwr->boundary_read.end(); ++j) {
      if(deps.find(*j) != deps.end()) {
        auto src = deps[*j];
        for(auto k=src.begin();k != src.end(); ++k) {
          sub_rdwr->after[i].insert(*k);
          std::cout << "add_after(" << sub_name << ")=" << i << "," << *k << std::endl;
        }
      }
    }
  }

  deps.clear();

  for(int i=0;i<n;i++) {
    std::string sub_name = group->scheditems[i].name;
    read_write_info *sub_rdwr = &(*rdwr_map)[sub_name];

    for(auto j=sub_rdwr->interior_write.begin(); j != sub_rdwr->interior_write.end(); ++j) {
      deps[*j].insert(i);
    }
  }
  for(int i=0;i<n;i++) {
    std::string sub_name = group->scheditems[i].name;
    read_write_info *sub_rdwr = &(*rdwr_map)[sub_name];

    for(auto j=sub_rdwr->interior_read.begin(); j != sub_rdwr->interior_read.end(); ++j) {
      if(deps.find(*j) != deps.end()) {
        auto src = deps[*j];
        for(auto k=src.begin();k != src.end(); ++k) {
          sub_rdwr->after[i].insert(*k);
          std::cout << "add_after(" << sub_name << ")=" << i << "," << *k << std::endl;
        }
      }
    }
  }
}
