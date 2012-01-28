/*@@
   @file      DebugDefines.c
   @date      Tue 2 Jul 2001
   @author    Thomas Radke
   @desc
              Routines to provide some debugging support for the Cactus code.
   @enddesc
   @version   $Id$
 @@*/

#include "cctk_Config.h"
#include "cctk_Flesh.h"
#include "cctk_DebugDefines.h"

static const char *rcsid = "$Header$";

CCTK_FILEVERSION(main_DebugDefines_c);


/********************************************************************
 *********************     External Routines   **********************
 ********************************************************************/

 /*@@
   @routine    CCTK_GFIndex?D
   @date       Tue 2 Jul 2001
   @author     Thomas Radke
   @desc
               Compute the linear index of a grid function element
               from its spatial indices
   @enddesc

   @var        GH
   @vdesc      pointer to CCTK grid hierarchy extension
   @vtype      const cGH *
   @vio        in
   @endvar
   @var        i, j, k, l
   @vdesc      spatial indices
   @vtype      int
   @vio        in
   @endvar

   @returntype int
   @returndesc
               the linear index for the given spatial indices
   @endreturndesc
@@*/
int CCTK_GFIndex1D (const cGH *GH, int i)
{
  GH = GH;
  return (i);
}

int CCTK_GFIndex2D (const cGH *GH, int i, int j)
{
  return (i + GH->cctk_lsh[0]*j);
}

int CCTK_GFIndex3D (const cGH *GH, int i, int j, int k)
{
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*k));
}

int CCTK_GFIndex4D (const cGH *GH, int i, int j, int k, int l)
{
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*(k + GH->cctk_lsh[2] * l)));
}

int CCTK_VectGFIndex1D (const cGH *GH, int i, int n)
{
  return (i + GH->cctk_lsh[0]*n);
}

int CCTK_VectGFIndex2D (const cGH *GH, int i, int j, int n)
{
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*n));
}

int CCTK_VectGFIndex3D (const cGH *GH, int i, int j, int k, int n)
{
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*(k + GH->cctk_lsh[2]*n)));
}

int CCTK_VectGFIndex4D (const cGH *GH, int i, int j, int k, int l, int n)
{
  return (i + GH->cctk_lsh[0]*(j + GH->cctk_lsh[1]*(k + GH->cctk_lsh[2]*
                                                    (l + GH->cctk_lsh[3]*n))));
}
