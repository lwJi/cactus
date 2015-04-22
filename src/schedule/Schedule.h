 /*@@
   @header    Schedule.h
   @date      Mon Sep 13 12:24:48 1999
   @author    Tom Goodale
   @desc 
   Header file for Schedule routines, etc.
   @enddesc 
   @version $Header$
 @@*/

#include "cctk_Schedule.h"
#include "cctki_Schedule.h"
#include "StoreHandledData.h"

#ifndef _SCHEDULE_H_
#define _SCHEDULE_H_

#ifdef __cplusplus
extern "C" {
#endif


int *CCTKi_ScheduleCreateIVec(int size);
void CCTKi_ScheduleDestroyIVec(int size, int *vector);
signed char **CCTKi_ScheduleCreateArray(int size);
void CCTKi_ScheduleDestroyArray(int size, signed char **array);

int CCTKi_ScheduleAddRow(int size, 
                         signed char **array, 
                         int *order, 
                         int item, 
                         int *thisorders);

int CCTKi_ScheduleSort(int size, signed char **array, int *order);

cHandledData *CCTKi_ScheduleGetGroups(void);

cHandledData *CCTKi_DoScheduleGetGroups(void);

#ifdef __cplusplus
}
#endif

/* Internal type data */

typedef enum {schedpoint_misc, schedpoint_analysis} iSchedPoint;

/* Timer data for a routine in a given schedule bin */
typedef struct t_timer
{
  struct t_timer *next;
  int timer_handle;
  char *schedule_bin;
  int has_been_output;
} t_timer;

typedef enum {sched_item_none, sched_group, sched_function} t_sched_item_type;

typedef struct
{
  /* Static data */
  char *description;

  /*char *thorn; MOVED TO FunctionData */
  char *implementation;

  //iSchedType type;
  t_sched_item_type type;

  cFunctionData FunctionData;

  int n_mem_groups;
  int *mem_groups;
  int *timelevels;

  int n_comm_groups;
  int *comm_groups;

  /* Timer data */
  t_timer *timers;

  /* Dynamic data */
  int *CommOnEntry;
  int *StorageOnEntry;

  int done_entry;
  int synchronised;

} t_attribute;

typedef enum {sort_order_none, sort_order_ascending, sort_order_descending} t_sort_order;

typedef struct
{
  char *name;
  
  t_sched_item_type type;

  void *function;
  int group;

  int n_whiles;
  char **whiles;
  int n_ifs;
  char **ifs;

  t_attribute *attributes;

  t_sched_modifier *modifiers;
} t_sched_item;

typedef struct 
{
  char *name;
  int *order;
  
  int n_scheditems;
  
  t_sched_item *scheditems;

} t_sched_group;


#endif
