{ This file was automatically created by Lazarus. Do not edit!
This source is only used to compile and install the package.
 }

unit lazdaemon; 

interface

uses
  reglazdaemon, daemonapp, LazarusPackageIntf; 

implementation

procedure Register; 
begin
  RegisterUnit('reglazdaemon', @reglazdaemon.Register); 
end; 

initialization
  RegisterPackage('lazdaemon', @Register); 
end.
