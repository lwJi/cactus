 /*@@
   @header    cctki_ScheduleBindings.h
   @date      Thu Jan 27 10:39:40 2000
   @author    Tom Goodale
   @desc 
   Routines which should be called from the bindings and rest of cactus
   to do schedule stuff, but is cactus specific, not in the core schedule
   subsystem.
   @enddesc
   @version $Header$
 @@*/

#ifndef _CCTKI_SCHEDUULEBINDINGS_H_
#define _CCTKI_SCHEDUULEBINDINGS_H_

#ifdef __cplusplus
extern "C" 
{
#endif

int CCTKi_ScheduleFunction(void *function,
                           const char *name,
                           const char *thorn,
                           const char *implementation,
                           const char *description,
                           const char *where,
                           const char *language,
                           int n_mem_groups,
                           int n_comm_groups,
                           int n_trigger_groups,
                           int n_sync_groups,
                           int n_writes,
                           int n_reads,
                           int n_invalidates,
                           int n_options,
                           int n_before,
                           int n_after,
                           int n_while,
                           int n_if,
                           const int *timelevels, 
                           ...);

int CCTKi_ScheduleGroup(const char *realname,
                        const char *name,
                        const char *thorn,
                        const char *implementation,
                        const char *description,
                        const char *where,
                        int n_mem_groups,
                        int n_comm_groups,
                        int n_trigger_groups,
                        int n_sync_groups,
                        int n_writes,
                        int n_reads,
                        int n_invalidates,
                        int n_options,
                        int n_before,
                        int n_after,
                        int n_while,
                        int n_if,
                        const int *timelevels,
                        ...
                        );

/* Same as CCTKi_ScheduleFunction and CCTKi_ScheduleGroup, but taking
   the clause lists as arrays instead of variable arguments. This is
   used for schedule blocks with conditional clauses, where the number
   of clauses is only known at run time. */
int CCTKi_ScheduleFunctionArrays(void *function,
                                 const char *name,
                                 const char *thorn,
                                 const char *implementation,
                                 const char *description,
                                 const char *where,
                                 const char *language,
                                 int n_mem_groups,
                                 int n_comm_groups,
                                 int n_trigger_groups,
                                 int n_sync_groups,
                                 int n_writes,
                                 int n_reads,
                                 int n_invalidates,
                                 int n_options,
                                 int n_before,
                                 int n_after,
                                 int n_while,
                                 int n_if,
                                 const int *timelevels,
                                 const char *const *mem_groups,
                                 const char *const *comm_groups,
                                 const char *const *trigger_groups,
                                 const char *const *sync_groups,
                                 const char *const *writes,
                                 const char *const *reads,
                                 const char *const *invalidates,
                                 const char *const *options,
                                 const char *tags,
                                 const char *const *before,
                                 const char *const *after,
                                 const char *const *whiles,
                                 const char *const *ifs);

int CCTKi_ScheduleGroupArrays(const char *realname,
                              const char *name,
                              const char *thorn,
                              const char *implementation,
                              const char *description,
                              const char *where,
                              int n_mem_groups,
                              int n_comm_groups,
                              int n_trigger_groups,
                              int n_sync_groups,
                              int n_writes,
                              int n_reads,
                              int n_invalidates,
                              int n_options,
                              int n_before,
                              int n_after,
                              int n_while,
                              int n_if,
                              const int *timelevels,
                              const char *const *mem_groups,
                              const char *const *comm_groups,
                              const char *const *trigger_groups,
                              const char *const *sync_groups,
                              const char *const *writes,
                              const char *const *reads,
                              const char *const *invalidates,
                              const char *const *options,
                              const char *tags,
                              const char *const *before,
                              const char *const *after,
                              const char *const *whiles,
                              const char *const *ifs);

int CCTKi_ScheduleGroupStorage(const char *group, int timelevels);

int CCTKi_ScheduleGroupComm(const char *group);

int CCTKi_ScheduleGHInit(void *GH);

#ifdef __cplusplus
}
#endif

#endif /* _CCTKI_SCHEDUULEBINDINGS_H_*/
