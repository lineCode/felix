Package: src/packages/linux.fdoc


=========================
Specialised Linux Support
=========================

============== ============================
key            file                         
============== ============================
plat_linux.hpp $PWD/src/plat/plat_linux.hpp 
plat_linux.cpp $PWD/src/plat/plat_linux.cpp 
============== ============================


Linux Support
=============

Stuff that works on Linux but not other platforms.

We only have a function here to get the number
of CPUs, the Linux way. Since it parses the /proc/stat
file, this suggests a more general way of accessing
the /proc directory would make sense.


.. code-block:: cpp

  //[plat_linux.hpp]
  #ifndef __PLAT_LINUX_H__
  #define __PLAT_LINUX_H__
  int get_cpu_nr();
  #endif

.. code-block:: cpp

  //[plat_linux.cpp]
  #define STAT "/proc/stat"
  #include <stdio.h>
  #include <errno.h>
  #include <stdlib.h>
  #include <string.h>
  
  #include "plat_linux.hpp"
  
  // return number of cpus
  int get_cpu_nr()
  {
     FILE *fp;
     char line[16];
     int proc_nb, cpu_nr = -1;
  
     if ((fp = fopen(STAT, "r")) == NULL) {
        fprintf(stderr, ("Cannot open %s: %s\n"), STAT, strerror(errno));
        exit(1);
     }
  
     while (fgets(line, 16, fp) != NULL) {
  
        if (strncmp(line, "cpu ", 4) && !strncmp(line, "cpu", 3)) {
           char* endptr = NULL;
           proc_nb = strtol(line + 3, &endptr, 0);
  
           if (!(endptr && *endptr == '\0')) {
             fprintf(stderr, "unable to parse '%s' as an integer in %s\n", line + 3, STAT);
             exit(1);
           }
  
           if (proc_nb > cpu_nr)
              cpu_nr = proc_nb;
        }
     }
  
     fclose(fp);
  
     return (cpu_nr + 1);
  }

