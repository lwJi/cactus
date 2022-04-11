 /*@@
   @file      ParseFile.c
   @date      Tue Jan 12 15:58:31 1999
   @author    Tom Goodale
   @desc
              Routines to read in a parameter file and pass the resulting data
              to a user-supplied subroutine.
              Currently taken from the old cactus ones and slightly modifed.
   @enddesc
 @@*/

/*#define DEBUG*/

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <string.h>

#include "cctk_CommandLine.h"
#include "cctk_Flesh.h"
#include "cctk_WarnLevel.h"

#include "util_String.h"

static const char *rcsid = "$Header$";

CCTK_FILEVERSION(util_ParseFile_c);

/********************************************************************
 *********************     Local Data Types   ***********************
 ********************************************************************/

/********************************************************************
 ********************* Local Routine Prototypes *********************
 ********************************************************************/

static char *ReadFile(FILE *file, long *filesize);


/********************************************************************
 ********************* Other Routine Prototypes *********************
 ********************************************************************/

/********************************************************************
 **********************     Local Data   *****************************
 ********************************************************************/

/********************************************************************
 *********************     External Routines   **********************
 ********************************************************************/

 /*@@
   @routine CCTKi_ParseFile
   @author Paul Walker, Frank Loeffler
   @desc
   This routine actually parses the parameter file. The
   syntax we allow is
   <ul>
     <li>a = b
         <li>a,b,c = d,e,f
         <li># rest of the line is ignored
         <li>x = "string value"
   </ul>
   So it is easy to parse
   <p>
   We go through the file looking for stuff and then set
   it in the global database using calls to the passed in set_function.
   @enddesc
   @history
   @hdate Tue Jan 12 16:41:36 1999 @hauthor Tom Goodale
   @hdesc Moved to CCTK.
          Changed to pass data to arbitrary function.
          Changed to take a file descriptor rather than a filename.
          Use a buffer to parse which can be preprocessed before main parsing
   @endhistory
   @var     ifp
   @vdesc   The filestream to parse
   @vtype   FILE *
   @vio     in
   @vcomment

   @endvar
   @var     set_function
   @vdesc   The function to call to set the value of a parameter
   @vtype   int (*)(const char *, const char *)
   @vio     in
   @vcomment

   @endvar
   @var     ConfigData
   @vdesc   Flesh configuration data
   @vtype   tFleshConfig *
   @vio     in
   @vcomment

   @endvar

   @returntype int
   @returndesc
   0 - success
   >0 - number of errors encountered
   @endreturndesc
@@*/

int CCTKi_ParseFile(FILE *ifp,
                    int (*set_function)(const char *, const char *, int),
                    tFleshConfig *ConfigData)
{
  int retval=1;
  long buffersize;
  char *buffer = ReadFile(ifp, &buffersize);
  if (!buffer)
    return 1;

    /* using Piraha only */
  buffersize = strlen(buffer);

  retval = CCTKi_PirahaParser(buffer, buffersize, set_function);
  free(buffer);
  return retval;
}

/********************************************************************
 *********************     Local Routines   *************************
 ********************************************************************/


/* #define TEST_ParseFile */

#ifdef TEST_ParseFile

int parameter_printer(const char *param, const char *val)
{
  printf("Parameter %s has value %s\n", param, val);

  return 0;
}

int main(int argc, char *argv[])
{
  int retval;
  FILE *parameter_file;

  if(argc > 1)
  {
    parameter_file = fopen(argv[1], "r");
    if(parameter_file)
    {
      CCTKi_ParseFile(parameter_file, parameter_printer);
      fclose(parameter_file);
      retval = 0;
    }
    else
    {
      retval=2;
    }
  }
  else
  {
    printf("Usage: %s <filename>\n", argv[0]);
    retval = 1;
  };

  return 0;
}

#endif


 /*@@
   @routine ReadFile
   @author Frank Loeffler
   @desc
   This routine reads a file into a buffer
   @enddesc
   @history
   @var     file
   @vdesc   The filestream to read
   @vtype   FILE *
   @vio     in
   @vcomment

   @endvar
   @var     filesize
   @vdesc   The size of the file
   @vtype   *long
   @vio     out
   @vcomment

   @endvar

   @returntype char *
   @returndesc
   NULL - failure
   !NULL allocated buffer
   @endreturndesc
@@*/
static char *ReadFile(FILE *file, long *filesize)
{
  char *buffer;

  if (!file)
  {
    fprintf(stderr, "Could not use file for reading.\n");
    return NULL;
  }
  /* Get the file size */
  int ierr = fseek(file, 0, SEEK_END);
  if (ierr < 0)
  {
    fprintf(stderr, "Could not seek to end of file: %s\n", strerror(errno));
    return NULL;
  }
  *filesize = ftell(file);
  if (*filesize < 0)
  {
    fprintf(stderr, "Could not determine file size: %s\n", strerror(errno));
    return NULL;
  }
  ierr = fseek(file, 0, SEEK_SET);
  if (ierr < 0)
  {
    fprintf(stderr, "Could not rewind file: %s\n", strerror(errno));
    return NULL;
  }
  /* Allocate buffer */
  buffer = (char *)malloc(*filesize+1);
  if (!buffer)
  {
    fprintf(stderr, "Could not allocate %ld bytes of memory.\n", *filesize+1);
    return NULL;
  }
  /* Read file into buffer and return */
  size_t iret = fread(buffer, *filesize, 1, file);
  if (iret < 1 && ferror(file))
  {
    fprintf(stderr, "Could not read data from file: %s\n", strerror(errno));
    return NULL;
  }
  /* Protect buffer for string operations */
  buffer[*filesize] = '\0';
  return buffer;
}

 

