/*@@
   @header    cctk.h
   @date      Tue Jan 26 17:29:34 1999
   @author    Tom Goodale
   @desc
              Main include file for the CCTK.
              All thorns should include this.
   @enddesc
   @version   $Header$
 @@*/

#ifndef _CCTK_CORE_H_
#define _CCTK_CORE_H_ 1

/* Grab the main configuration info. */
#include "cctk_Config.h"

/* Define which thorn the file is in */
#include "definethisthorn.h"

/* Include the constants */
#include "cctk_Constants.h"

/* Define some stuff */

#ifdef FCODE

#include "cctk_Faces.h"
#include "cctk_Interp.h"
#include "cctk_Loop.h"
#include "cctk_WarnLevel.h"

#define CCTK_PRINTSEPARATOR\
  print '("--------------------------------------------------------------------------------")'

#define _CCTK_FARGUMENTS \
cctk_dim,cctk_gsh,cctk_lsh,cctk_lbnd,cctk_ubnd,cctk_lssh,cctk_from,cctk_to,\
cctk_bbox,cctk_delta_time,cctk_time,cctk_delta_space,cctk_origin_space,\
cctk_levfac,cctk_levoff,cctk_levoffdenom,cctk_timefac,cctk_convlevel,\
cctk_convfac,cctk_nghostzones,cctk_iteration,cctkGH,\
cctk_lsh1,cctk_lsh2,cctk_lsh3

#define _DECLARE_CCTK_ARGUMENTS _DECLARE_CCTK_FARGUMENTS
#define _DECLARE_CCTK_FARGUMENTS &&\
        CCTK_DECLARE(INTEGER,cctk_dim,)&&\
        CCTK_DECLARE(INTEGER,cctk_gsh,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_lsh,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_lbnd,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_ubnd,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_lssh,(CCTK_NSTAGGER*cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_from,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_to,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_bbox,(2*cctk_dim))&&\
        CCTK_DECLARE(CCTK_REAL,cctk_delta_time,)&&\
        CCTK_DECLARE(CCTK_REAL,cctk_time,)&&\
        CCTK_DECLARE(CCTK_REAL,cctk_delta_space,(cctk_dim))&&\
        CCTK_DECLARE(CCTK_REAL,cctk_origin_space,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_levfac,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_levoff,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_levoffdenom,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_timefac,)&&\
        CCTK_DECLARE(INTEGER,cctk_convlevel,)&&\
        CCTK_DECLARE(INTEGER,cctk_convfac,)&&\
        CCTK_DECLARE(INTEGER,cctk_nghostzones,(cctk_dim))&&\
        CCTK_DECLARE(INTEGER,cctk_iteration,)&&\
        CCTK_DECLARE(CCTK_POINTER,cctkGH,)&&\
        CCTK_DECLARE(INTEGER,cctk_lsh1,)&&\
        CCTK_DECLARE(INTEGER,cctk_lsh2,)&&\
        CCTK_DECLARE(INTEGER,cctk_lsh3,)&&

#define CCTK_WARN(a,b) CCTK_Warn(a,__LINE__,__FORTRANFILE__,CCTK_THORNSTRING,b)

#define CCTK_CoordRegisterSystem(a,b,c) CCTKi_CoordRegisterSystem(a,b,CCTK_THORNSTRING,c)

/* John Shalf says that the operator .ne. needs to be enclosed by
   spaces, because ANSI C preprocessors otherwise interpret the
   character sequence ".0" as preprocessor token */
#define CCTK_EQUALS(a,b) (CCTK_Equals(a,b) .ne. 0)

#define CCTK_PASS_FTOF CCTK_FARGUMENTS

#define CCTK_ORIGIN_SPACE(x) (cctk_origin_space(x)+cctk_delta_space(x)/cctk_levfac(x)*cctk_levoff(x)/cctk_levoffdenom(x))
#define CCTK_DELTA_SPACE(x) (cctk_delta_space(x)/cctk_levfac(x))
#define CCTK_DELTA_TIME (cctk_delta_time/cctk_timefac)
/* The "stagger index" stag is zero-based (0,1,...), the direction dim
   is one-based in Fortran (1,2,3,...) */
#define CCTK_LSSH(stag,dim) cctk_lssh(CCTK_LSSH_IDX(stag,dim))
#define CCTK_LSSH_IDX(stag,dim) (1+(stag)+CCTK_NSTAGGER*((dim)-1))

#ifdef F90CODE

#define _DECLARE_CCTK_FUNCTIONS                   \
  external     CCTK_PointerTo                   &&\
  CCTK_POINTER CCTK_PointerTo                   &&\
  interface                                     &&\
     integer function CCTK_Equals (arg1, arg2)  &&\
       implicit none                            &&\
       CCTK_POINTER_TO_CONST arg1               &&\
       character(*) arg2                        &&\
     end function CCTK_Equals                   &&\
     integer function CCTK_MyProc (cctkGH)      &&\
       implicit none                            &&\
       CCTK_POINTER_TO_CONST cctkGH             &&\
     end function CCTK_MyProc                   &&\
     integer function CCTK_nProcs (cctkGH)      &&\
       implicit none                            &&\
       CCTK_POINTER_TO_CONST cctkGH             &&\
     end function CCTK_nProcs                   &&\
     integer function CCTK_IsThornActive (name) &&\
       implicit none                            &&\
       character(*) name                        &&\
     end function CCTK_IsThornActive            &&\
     CCTK_POINTER function CCTK_NullPointer ()  &&\
       implicit none                            &&\
     end function CCTK_NullPointer              &&\
  end interface                                 &&

#else /* ! F90CODE */

#define _DECLARE_CCTK_FUNCTIONS \
  integer      CCTK_Equals, CCTK_MyProc, CCTK_nProcs, CCTK_IsThornActive &&\
  external     CCTK_Equals, CCTK_MyProc, CCTK_nProcs, CCTK_IsThornActive &&\
  CCTK_POINTER CCTK_PointerTo, CCTK_NullPointer &&\
  external     CCTK_PointerTo, CCTK_NullPointer &&

#endif /* ! F90CODE */

#endif /*FCODE*/

#ifdef CCODE

/* get the definition of ptrdiff_t */
#include <stddef.h>

#include "cGH.h"

#include "cctk_ActiveThorns.h"
#include "cctk_Banner.h"
#include "cctk_Cache.h"
#include "cctk_Coord.h"
#include "cctk_Comm.h"
#include "cctk_CommandLine.h"
#include "cctk_Complex.h"
#include "cctk_DebugDefines.h"
#include "cctk_Faces.h"
#include "cctk_File.h"
#include "cctk_Flesh.h"
#include "cctk_FortranString.h"
#include "cctk_Functions.h"
#include "cctk_GHExtensions.h"
#include "cctk_Groups.h"
#include "cctk_GroupsOnGH.h"
#include "cctk_Interp.h"
#include "cctk_IO.h"
#include "cctk_IOMethods.h"
#include "cctk_Loop.h"
#include "cctk_Main.h"
#include "cctk_Malloc.h"
#include "cctk_Misc.h"
#include "cctk_Parameter.h"
#include "cctk_Reduction.h"
#include "cctk_Stagger.h"
#include "cctk_Sync.h"
#include "cctk_Timers.h"
#include "cctk_Termination.h"
#include "cctk_WarnLevel.h"

/* Include prototypes for scheduled functions */
#include "cctk_ScheduleFunctions.h"

/* Include prototypes for scheduled functions */
#include "cctk_ScheduleFunctions.h"

/* Include definitions provided by capabilities */
#include "cctk_Capabilities.h"

/*
 * routines/macros to compute the linear index
 * of a grid funtion element from its i/j/k dimensions
 *
 * These are defined as inline functions when the language supports this,
 * otherwise they are defined as macros.
 * For CCTK_DEBUG these are external C routines defined in DebugDefines.c.
 */

#ifdef __cplusplus
#  define HAVE_INLINE
#else
#  ifdef HAVE_CCTK_C_INLINE
#    define HAVE_INLINE
#  endif
#endif

#ifdef HAVE_INLINE

/* The "inline" keyword is supported */

static inline int CCTK_GFINDEX0D (const cGH *GH);
static inline int CCTK_GFINDEX0D (const cGH *GH)
{
  return (0);
}

static inline int CCTK_GFINDEX1D (const cGH *GH, int i);
static inline int CCTK_GFINDEX1D (const cGH *GH, int i)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d cctk_lsh=[%d]",
                i, GH->cctk_lsh[0]);
  }
#endif
  return (i);
}

static inline int CCTK_GFINDEX2D (const cGH *GH, int i, int j);
static inline int CCTK_GFINDEX2D (const cGH *GH, int i, int j)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0] ||
      j < 0 || j >= GH->cctk_lsh[1])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d j=%d cctk_lsh=[%d,%d]",
                i, j, GH->cctk_lsh[0], GH->cctk_lsh[1]);
  }
#endif
  return (i + GH->cctk_lsh[0]*j);
}

static inline int CCTK_GFINDEX3D (const cGH *GH, int i, int j, int k);
static inline int CCTK_GFINDEX3D (const cGH *GH, int i, int j, int k)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0] ||
      j < 0 || j >= GH->cctk_lsh[1] ||
      k < 0 || k >= GH->cctk_lsh[2])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d j=%d k=%d cctk_lsh=[%d,%d,%d]",
                i, j, k, GH->cctk_lsh[0], GH->cctk_lsh[1], GH->cctk_lsh[2]);
  }
#endif
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*k));
}

static inline int CCTK_GFINDEX4D (const cGH *GH, int i, int j, int k, int l);
static inline int CCTK_GFINDEX4D (const cGH *GH, int i, int j, int k, int l)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0] ||
      j < 0 || j >= GH->cctk_lsh[1] ||
      k < 0 || k >= GH->cctk_lsh[2] ||
      l < 0 || l >= GH->cctk_lsh[3])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d j=%d k=%d l=%d cctk_lsh=[%d,%d,%d,%d]",
                i, j, k, l, GH->cctk_lsh[0], GH->cctk_lsh[1], GH->cctk_lsh[2], GH->cctk_lsh[3]);
  }
#endif
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*(k + GH->cctk_lsh[2]*l)));
}

static inline int CCTK_VECTGFINDEX0D (const cGH *GH, int n);
static inline int CCTK_VECTGFINDEX0D (const cGH *GH, int n)
{
#ifdef CCTK_DEBUG
  if (n < 0)
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Vector index out of bounds.  n=%d",
                n);
  }
#endif
  return (n);
}

static inline int CCTK_VECTGFINDEX1D (const cGH *GH, int i, int n);
static inline int CCTK_VECTGFINDEX1D (const cGH *GH, int i, int n)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d cctk_lsh=[%d]",
                i, GH->cctk_lsh[0]);
  }
  if (n < 0)
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Vector index out of bounds.  n=%d",
                n);
  }
#endif
  return (i + GH->cctk_lsh[0]*n);
}

static inline int CCTK_VECTGFINDEX2D (const cGH *GH, int i, int j, int n);
static inline int CCTK_VECTGFINDEX2D (const cGH *GH, int i, int j, int n)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0] ||
      j < 0 || j >= GH->cctk_lsh[1])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d j=%d cctk_lsh=[%d,%d]",
                i, j, GH->cctk_lsh[0], GH->cctk_lsh[1]);
  }
  if (n < 0)
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Vector index out of bounds.  n=%d",
                n);
  }
#endif
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*n));
}

static inline int CCTK_VECTGFINDEX3D (const cGH *GH,
                                      int i, int j, int k, int n);
static inline int CCTK_VECTGFINDEX3D (const cGH *GH,
                                      int i, int j, int k, int n)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0] ||
      j < 0 || j >= GH->cctk_lsh[1] ||
      k < 0 || k >= GH->cctk_lsh[2])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d j=%d k=%d cctk_lsh=[%d,%d,%d]",
                i, j, k, GH->cctk_lsh[0], GH->cctk_lsh[1], GH->cctk_lsh[2]);
  }
  if (n < 0)
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Vector index out of bounds.  n=%d",
                n);
  }
#endif
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*(k + GH->cctk_lsh[2]*n)));
}

static inline int CCTK_VECTGFINDEX4D (const cGH *GH,
                                      int i, int j, int k, int l, int n);
static inline int CCTK_VECTGFINDEX4D (const cGH *GH,
                                      int i, int j, int k, int l, int n)
{
#ifdef CCTK_DEBUG
  if (i < 0 || i >= GH->cctk_lsh[0] ||
      j < 0 || j >= GH->cctk_lsh[1] ||
      k < 0 || k >= GH->cctk_lsh[2] ||
      l < 0 || l >= GH->cctk_lsh[3])
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Grid function index out of bounds.  i=%d j=%d k=%d l=%d cctk_lsh=[%d,%d,%d,%d]",
                i, j, k, l, GH->cctk_lsh[0], GH->cctk_lsh[1], GH->cctk_lsh[2], GH->cctk_lsh[3]);
  }
  if (n < 0)
  {
    CCTK_VWarn (CCTK_WARN_ABORT,
                __LINE__, __FILE__, CCTK_THORNSTRING,
                "Vector index out of bounds.  n=%d",
                n);
  }
#endif
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*(k + GH->cctk_lsh[2]*
                                                    (l + GH->cctk_lsh[3]*n))));
}

#else /* ! defined(HAVE_INLINE) */

#ifdef CCTK_DEBUG
/* The "inline" keyword is not supported, and we want to debug */

#define CCTK_GFINDEX0D CCTK_GFIndex0D
#define CCTK_GFINDEX1D CCTK_GFIndex1D
#define CCTK_GFINDEX2D CCTK_GFIndex2D
#define CCTK_GFINDEX3D CCTK_GFIndex3D
#define CCTK_GFINDEX4D CCTK_GFIndex4D
#define CCTK_VECTGFINDEX0D CCTK_VectGFIndex0D
#define CCTK_VECTGFINDEX1D CCTK_VectGFIndex1D
#define CCTK_VECTGFINDEX2D CCTK_VectGFIndex2D
#define CCTK_VECTGFINDEX3D CCTK_VectGFIndex3D
#define CCTK_VECTGFINDEX4D CCTK_VectGFIndex4D

#else /* ! defined(CCTK_DEBUG) */
/* The "inline" keyword is not supported, and we want to optimise */

#define CCTK_GFINDEX0D(GH)                      \
  (0)
#define CCTK_GFINDEX1D(GH, i)                   \
  (i)
#define CCTK_GFINDEX2D(GH, i, j)                \
  ((i) + (GH)->cctk_lsh[0] * (j))
#define CCTK_GFINDEX3D(GH, i, j, k)             \
  ((i) + (GH)->cctk_lsh[0] *                    \
   ((j) + (GH)->cctk_lsh[1] * (k)))
#define CCTK_GFINDEX4D(GH, i, j, k, l)          \
  ((i) + (GH)->cctk_lsh[0] *                    \
   ((j) + (GH)->cctk_lsh[1] *                   \
    ((k) + (GH)->cctk_lsh[2] * (l))))
#define CCTK_VECTGFINDEX0D(GH, n)               \
  (n)
#define CCTK_VECTGFINDEX1D(GH, i, n)            \
  ((i) + (GH)->cctk_lsh[0] * (n))
#define CCTK_VECTGFINDEX2D(GH, i, j, n)         \
  ((i) + (GH)->cctk_lsh[0] *                    \
   ((j) + (GH)->cctk_lsh[1] * (n)))
#define CCTK_VECTGFINDEX3D(GH, i, j, k, n)      \
  ((i) + (GH)->cctk_lsh[0] *                    \
   ((j) + (GH)->cctk_lsh[1] *                   \
    ((k) + (GH)->cctk_lsh[2] * (n))))
#define CCTK_VECTGFINDEX4D(GH, i, j, k, l, n)   \
  ((i) + (GH)->cctk_lsh[0] *                    \
   ((j) + (GH)->cctk_lsh[1] *                   \
    ((k) + (GH)->cctk_lsh[2] *                  \
     ((l) + (GH)->cctk_lsh[3] * (n)))))

#endif /* ! defined(CCTK_DEBUG) */

#endif /* ! defined(HAVE_INLINE) */

#undef HAVE_INLINE



#define CCTK_PRINTSEPARATOR \
  printf("--------------------------------------------------------------------------------\n");

#define _DECLARE_CCTK_ARGUMENTS _DECLARE_CCTK_CARGUMENTS
#define _DECLARE_CCTK_CARGUMENTS \
        CCTK_DECLARE_INIT(ptrdiff_t,cctki_dummy_int,0);\
        CCTK_DECLARE_INIT(int const,cctk_dim,cctkGH->cctk_dim);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_gsh,cctkGH->cctk_gsh);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_lsh,cctkGH->cctk_lsh);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_lbnd,cctkGH->cctk_lbnd);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_ubnd,cctkGH->cctk_ubnd);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_lssh,cctkGH->cctk_lssh);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_from,cctkGH->cctk_from);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_to,cctkGH->cctk_to);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_bbox,cctkGH->cctk_bbox);\
        CCTK_DECLARE_INIT(CCTK_REAL const,cctk_delta_time,cctkGH->cctk_delta_time);\
        CCTK_DECLARE_INIT(CCTK_REAL const,cctk_time,cctkGH->cctk_time);\
        CCTK_DECLARE_INIT(CCTK_REAL const *CCTK_RESTRICT const,cctk_delta_space,cctkGH->cctk_delta_space);\
        CCTK_DECLARE_INIT(CCTK_REAL const *CCTK_RESTRICT const,cctk_origin_space,cctkGH->cctk_origin_space);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_levfac,cctkGH->cctk_levfac);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_levoff,cctkGH->cctk_levoff);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_levoffdenom,cctkGH->cctk_levoffdenom);\
        CCTK_DECLARE_INIT(int const,cctk_timefac,cctkGH->cctk_timefac);\
        CCTK_DECLARE_INIT(int const,cctk_convlevel,cctkGH->cctk_convlevel);\
        CCTK_DECLARE_INIT(int const,cctk_convfac,cctkGH->cctk_convfac);\
        CCTK_DECLARE_INIT(int const *CCTK_RESTRICT const,cctk_nghostzones,cctkGH->cctk_nghostzones);\
        CCTK_DECLARE_INIT(int const,cctk_iteration,cctkGH->cctk_iteration);\

#define _INITIALISE_CCTK_C2F
#define _DECLARE_CCTK_C2F
#define _PASS_CCTK_C2F(xGH) &((xGH)->cctk_dim),\
                            (xGH)->cctk_gsh,(xGH)->cctk_lsh,\
                            (xGH)->cctk_lbnd,(xGH)->cctk_ubnd,\
                            (xGH)->cctk_lssh,\
                            (xGH)->cctk_from,(xGH)->cctk_to,\
                            (xGH)->cctk_bbox,\
                            &((xGH)->cctk_delta_time), &((xGH)->cctk_time),\
                            (xGH)->cctk_delta_space, (xGH)->cctk_origin_space,\
                            (xGH)->cctk_levfac,\
                            (xGH)->cctk_levoff,\
                            (xGH)->cctk_levoffdenom,\
                            &((xGH)->cctk_timefac),\
                            &((xGH)->cctk_convlevel),\
                            &((xGH)->cctk_convfac),\
                            (xGH)->cctk_nghostzones,\
                            &((xGH)->cctk_iteration),\
                            &(xGH),\
                            &(xGH)->cctk_lsh[0],\
                            &(xGH)->cctk_lsh[1],\
                            &(xGH)->cctk_lsh[2]
#define _CCTK_C2F_PROTO     int const *,\
                            int const *, int const *,\
                            int const *, int const *,\
                            int const *,\
                            int const *, int const *,\
                            int const *,\
                            CCTK_REAL const *, CCTK_REAL const *,\
                            CCTK_REAL const *, CCTK_REAL const *,\
                            int const *,\
                            int const *,\
                            int const *,\
                            int const *,\
                            int const *,\
                            int const *,\
                            int const *,\
                            int const *,\
                            cGH const *const *,\
                            int const *,\
                            int const *,\
                            int const *

#define CCTK_EQUALS(a,b) (CCTK_Equals((a),(b)))

#define CCTK_PASS_CTOC cctkGH

#define CCTK_ORIGIN_SPACE(x) (cctk_origin_space[x]+cctk_delta_space[x]/cctk_levfac[x]*cctk_levoff[x]/cctk_levoffdenom[x])
#define CCTK_DELTA_SPACE(x) (cctk_delta_space[x]/cctk_levfac[x])
#define CCTK_DELTA_TIME (cctk_delta_time/cctk_timefac)
/* The "stagger index" stag is zero-based (0,1,...), the direction dim
   is zero-based in C (0,1,2,...) */
#define CCTK_LSSH(stag,dim) cctk_lssh[CCTK_LSSH_IDX(stag,dim)]
#define CCTK_LSSH_IDX(stag,dim) ((stag)+CCTK_NSTAGGER*(dim))

#define CCTK_WARN(a,b) CCTK_Warn(a,__LINE__,__FILE__,CCTK_THORNSTRING,b)

#define CCTK_MALLOC(s) CCTKi_Malloc(s,__LINE__,__FILE__)
#define CCTK_FREE(p) CCTKi_Free(p)

#endif /*CCODE*/

#define CCTK_INFO(a) CCTK_Info(CCTK_THORNSTRING,(a))
#define CCTK_PARAMWARN(a) CCTK_ParamWarn(CCTK_THORNSTRING,(a))

/*
#define CCTK_MAKESTRING(x) CCTK_REALSTRING(x)
#define CCTK_REALSTRING(x) #x
#define CCTK_WARN(a,b) CCTK_Warn(a,CCTK_MAKESTRING(CCTK_THORN),b,__LINE__,__FILE__)
*/


#endif
