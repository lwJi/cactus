#include "cctk.h"
#include <sys/types.h>
#include "schedule/Schedule.h"
#include <iostream>
#include <map>
#include <vector>
#include <set>
#include <algorithm>

inline char lc(char c) {
  if(c >= 'A' && c <= 'Z')
    return c + 'a'-'A';
  else
    return c;
}

struct read_write_info {
  std::map<std::string,std::set<int> > boundary;
  std::map<std::string,std::set<int> > interior;
  std::map<int,std::set<int> > after;
};

extern "C"
int CCTKi_rdwr_assign_after(read_write_info *rdwr,int item,int size,int *thisorders,t_sched_group *group) {
  auto src=rdwr->after[item];
  for(auto i=src.begin();i != src.end();++i) {
    if(*i == item)
      continue;
    if(thisorders[*i] == -1) {
      std::cout << "assign_after order error" << std::endl;
      return -1; // schedule order error
    }
    thisorders[*i] = 1;
  }
  return 0;
}

extern "C"
void CCTKi_rdwr_free(read_write_info *ptr) {
  delete ptr;
}

extern "C"
void CCTKi_rdwr_init(read_write_info **ptr,t_sched_group *group) {
  read_write_info *rdwr=0;
  rdwr = new read_write_info();
  *ptr = rdwr;
  const int n = group->n_scheditems;
  for(int i=0;i<n;i++) {
    t_attribute *attr = group->scheditems[i].attributes;
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
        rdwr->interior[info[0]].insert(i);
      } else if(info[1] == "boundary") {
        rdwr->boundary[info[0]].insert(i);
      } else {
        rdwr->interior[info[0]].insert(i);
        rdwr->boundary[info[0]].insert(i);
      }
    }
  }
  for(int i=0;i<n;i++) {
    t_attribute *attr = group->scheditems[i].attributes;
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
        auto src = rdwr->interior[info[0]];
        for(auto ix=src.begin();ix != src.end();++ix) { rdwr->after[i].insert(*ix); }
      } else if(info[1] == "boundary") {
        auto src = rdwr->boundary[info[0]];
        for(auto ix=src.begin();ix != src.end();++ix) { rdwr->after[i].insert(*ix); }
      } else {
        auto src = rdwr->interior[info[0]];
        for(auto ix=src.begin();ix != src.end();++ix) { rdwr->after[i].insert(*ix); }
        src = rdwr->boundary[info[0]];
        for(auto ix=src.begin();ix != src.end();++ix) { rdwr->after[i].insert(*ix); }
      }
    }
  }
}
