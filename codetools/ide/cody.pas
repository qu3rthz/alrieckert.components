{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit Cody; 

interface

uses
  PPUListDlg, CodyStrConsts, AddAssignMethodDlg, CodyCtrls, CodyFrm, 
  CodyRegistration, LazarusPackageIntf;

implementation

procedure Register; 
begin
  RegisterUnit('CodyRegistration', @CodyRegistration.Register); 
end; 

initialization
  RegisterPackage('Cody', @Register); 
end.
