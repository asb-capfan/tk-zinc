#
# Include the TEA standard macro set
#

builtin(include,tclconfig/tcl.m4)

#
# Zinc specific macros below.
#
#
# ALL the new macros here need to be modified to
# detect the various packages needed and to get their paths.
# Right now all this is statically defined in the macros.
#
#------------------------------------------------------------------------
# ZINC_ENABLE_GL --
#
#	Specify if openGL support should be used.
#	Code for managing a damage area can also be enabled.
#
# Arguments:
#	none
#	
# Results:
#
#	Adds the following arguments to configure:
#		--enable-gl=[yes,no,damage]
#
#	Defines the following vars:
#		GL_INCLUDES	OpenGL include files path
#		GL_LIBS		additional libraries needed for GL
#		LIBS		Modified to reflect the need of new
#				libraries
#		GL		Defined if GL support is enabled
#		GL_DAMAGE	Defined if damage support has been
#				requested
#
#------------------------------------------------------------------------

AC_DEFUN(ZINC_ENABLE_GL, [
     if test x"${TEA_INITED}" = x ; then
  	AC_MSG_ERROR([Must call TEA INIT before ENABLE_GL])
     fi

     AC_MSG_CHECKING([for build with GL])
     AC_ARG_ENABLE(gl,
 		  [  --enable-gl             build with openGL support (yes,no,damage) [[no]]],
 		  [tcl_ok=$enableval], [tcl_ok=no])

     if test "$tcl_ok" = "no"; then
 	GL_LIBS=
 	GL_INCLUDES=
 	AC_MSG_RESULT([no])
     else
	if test "${TEA_PLATFORM}" = "windows" ; then
	    GL_LIBS=-lopengl32
	else
	  #
	  # On Linux, the Nvidia GL libraries needs threads support via
	  # pthreads but not mesa. Need to auto-detect that and the
	  #  availability of pthreads.
 	  GL_LIBS="-lGL -lpthread"
# 	  GL_LIBS="-lGL"
 	  GL_INCLUDES='/usr/include'
        fi

 	AC_DEFINE(GL)
 	if test "$tcl_ok" = "damage"; then
 	    AC_DEFINE(GL_DAMAGE)
         fi

 	LIBS="$LIBS $GL_LIBS"

 	if test "$tcl_ok" = "yes"; then
 	    AC_MSG_RESULT([yes (standard)])
 	else
 	    AC_MSG_RESULT([yes (with damage support)])
 	fi
     fi

     AC_SUBST(GL_LIBS)
     AC_SUBST(GL_INCLUDES)
])

#------------------------------------------------------------------------
# ZINC_ENABLE_OM --
#
#	Specify if the anti overlapping code should be included.
#
# Arguments:
#	none
#	
# Results:
#
#	Adds the following arguments to configure:
#		--enable-om=[yes,no]
#
#	Defines the following vars:
#		Om_LIB_FILE	Contains the platform depent library
#				name for the pluggable overlap manager
#		OM		Defined if overlap manager support
#				is enabled
#
#	Adjust LIBS to include the overlap manager default library.
#	May Modify LD_SEARCH_FLAGS to include the zinc install directory
#
#------------------------------------------------------------------------

 AC_DEFUN(ZINC_ENABLE_OM, [
     if test x"${TEA_INITED}" = x ; then
  	AC_MSG_ERROR([Must call TEA INIT before ENABLE_OM])
     fi

     AC_MSG_CHECKING([for build with the overlap manager])
     AC_ARG_ENABLE(om,
 		  [  --enable-om             build with overlap manager support [[yes]]],
 		  [tcl_ok=$enableval], [tcl_ok=yes])
     if test "$tcl_ok" = "no"; then
 	Om_LIB_FILE=
 	AC_MSG_RESULT([no])
     else
	if test "${TEA_PLATFORM}" = "windows" ; then
	    Om_LIB_FILE=om.dll
	    bin_BINARIES="\$(Om_LIB_FILE) ${bin_BINARIES}"
	else
 	    Om_LIB_FILE=libom.so
	    aux_BINARIES="\$(Om_LIB_FILE) ${bin_BINARIES}"
	fi
 	AC_DEFINE(OM)
 	AC_MSG_RESULT([yes])
	LIBS="${LIBS} -L. -lom"
     fi
     AC_SUBST(Om_LIB_FILE)
])

#------------------------------------------------------------------------
# ZINC_ENABLE_SHAPE --
#
#	Specify if the X shape extension support should be included.
#
# Arguments:
#	none
#	
# Results:
#
#	Adds the following arguments to configure:
#		--enable-shape=[yes,no]
#
#	Defines the following vars:
#		SHAPE		Defined if shape support is enabled
#
#	Adjust LIBS to include the X extension library
#
#------------------------------------------------------------------------

AC_DEFUN(ZINC_ENABLE_SHAPE, [
     if test x"${TEA_INITED}" = x ; then
 	AC_MSG_ERROR([Must call TEA INIT before ENABLE_SHAPE])
     fi
     AC_MSG_CHECKING([for build with X shape support])
     AC_ARG_ENABLE(shape,
 		  [  --enable-shape          build with X shape support (if applicable) [[yes]]],
 		  [tcl_ok=$enableval], [tcl_ok=yes])
     if test "$tcl_ok" = "no"; then
 	AC_MSG_RESULT([no])
     else
         if test "${TEA_PLATFORM}" = "windows" ; then
 	    AC_MSG_RESULT([no (not available on windows)])
 	else
 	    AC_DEFINE(SHAPE)
 	    AC_MSG_RESULT([yes])
	    LIBS="${LIBS} -lXext"
 	fi
     fi
])

#------------------------------------------------------------------------
# ZINC_ENABLE_PTK --
#
#	Specify that zinc should be build for perl/Tk instead of Tk
#
# Arguments:
#	none
#	
# Results:
#
#	Adds the following arguments to configure:
#		--enable-ptk=[yes,no]
#
#	Defines the following vars:
#		PTK			Defined if compilation should be
#					done for perl/Tk
#		PERL_TK_LIB		Path to perl/tk library (.pm)
#
#	Modifies SHLIB_LD_LIBS, TCL_INCLUDES and TK_INCLUDES to
#	reflect the change in runtime environment.
#
#------------------------------------------------------------------------

AC_DEFUN(ZINC_ENABLE_PTK, [
     AC_MSG_CHECKING([for build with perl/Tk support])
     AC_ARG_ENABLE(ptk,
 		  [  --enable-ptk            build with perl/Tk support [[no]]],
 		  [tcl_ok=$enableval], [tcl_ok=no])
     if test "$tcl_ok" = "no"; then
	PERL_TK_LIB=
 	AC_MSG_RESULT([no])
     else
	#
	# Locate the perl hierarchy and the corresponding perl/tk.
	#
	AC_CHECK_PROGS(PERL, perl, error)
	changequote()
	PERL_TK_LIB=`perl -MTk -e 'print $Tk::library'`
	changequote([, ])

	#
	# Don't use stubs libraries with perl/Tk.
	# Don't use either the includes from Tcl/Tk.
	SHLIB_LD_LIBS="\${LIBS}"
	TCL_INCLUDES=
	TK_INCLUDES=-I${PERL_TK_LIB}/pTk
	AC_DEFINE(PTK)
 	AC_MSG_RESULT([yes])
     fi

     AC_SUBST(PERL_TK_LIB)
])
