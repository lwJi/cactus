////////////////////////////////////////////////////////////////////////////////
//  Copyright (c) 2011 Steve Brandt and Philip LeBlanc
//
//  Distributed under the Boost Software License, Version 1.0. (See accompanying
//  file BOOST_LICENSE_1_0.rst or copy at http://www.boost.org/LICENSE_1_0.txt)
////////////////////////////////////////////////////////////////////////////////
#ifndef SMART_PTR_HPP
#define SMART_PTR_HPP
#include <assert.h>
#include <set>

#ifndef NULL
#define NULL ((void*)0)
#endif

extern std::set<void*> ptrs;

template<typename T>
class smart_ptr;

template<typename T>
class smart_ptr_guts {
    int ref_count;
    public:
    T *ptr;
    smart_ptr_guts(int rc,T *p) : ref_count(rc), ptr(p) {
    }
    ~smart_ptr_guts() {
    	ptrs.erase((void*)ptr);
        delete ptr;
    }
    void inc() {
        ref_count++;
    }
    bool dec() {
        int r = ref_count;
        if(ref_count>0)
            ref_count--;
        return r==1;
    }
    int ref_count_() {
        return ref_count;
    }
};

// Count references to an object in a thread-safe
// way using pthreads and do automatic clean up.
template<typename T>
class smart_ptr {
    smart_ptr_guts<T> *guts;
    void clean() {
        assert(this != NULL);
        if(guts != NULL && guts->dec()) {
            delete guts;
            guts = NULL;
        }
    }
    public:
    void inc() {
        if(valid())
            guts->inc();
    }
    smart_ptr(T *ptr) {
        if(ptr == NULL) {
            guts = NULL;
        } else {
    		assert(ptrs.find((void*)ptr) == ptrs.end());
    		ptrs.insert(ptr);
            guts = new smart_ptr_guts<T>(1,ptr);
        }
    }
    smart_ptr(const smart_ptr<T> &sm) : guts(sm.guts) {
        if(sm.guts != NULL)
            guts->inc();
    }
    smart_ptr() : guts(NULL) {}
    ~smart_ptr() {
        clean();
    }
    void operator=(T *t) {
        clean();
        if(t == NULL) {
            guts = NULL;
        } else {
            guts = new smart_ptr_guts<T>(1,t);
        }
    }
    void operator=(const smart_ptr<T>& s) {
        assert(this != NULL);
        clean();
        guts = s.guts;
        if(guts != NULL)
            guts->inc();
    }
    T& operator*() {
        assert(guts != NULL);
        return *guts->ptr;
    }
    T *operator->() const {
        if(guts == NULL)
            return NULL;
        else
            return guts->ptr;
    }
    T *ptr() {
        assert(guts != NULL);
        return guts->ptr;
    }
    bool valid() {
        return guts != NULL && guts->ptr != NULL;
    }
    int ref_count() {
        assert(guts != NULL);
        return guts->ref_count_();
    }
    template<typename C>
    smart_ptr<C> dup() {
        smart_ptr<C> c;
        c.guts = (smart_ptr_guts<C> *)guts;
        guts->inc();
        return c;
    }
    template<typename C>
    friend class smart_ptr;
};
#endif
