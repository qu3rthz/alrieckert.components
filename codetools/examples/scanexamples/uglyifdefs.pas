unit UglyIFDEFs;
{$mode objfpc}{$H+}

{$ifndef MPI_INCLUDED}
{$define MPI_INCLUDED}

{$endif}

{$if defined(__cplusplus)}
// only comments and spaces
{$endif}

interface

uses
  Classes, SysUtils;

{$define HAVE_MPI_OFFSET}

{$if !defined(MPI_BUILD_PROFILING)}
{$ENDIF}

{$define HAVE_MPI_GREQUEST}
{$ifndef HAVE_MPI_GREQUEST}
{$endif}

{$undef MPI_File_f2c}

implementation

end.

