{ This file was automatically created by Lazarus. do not edit ! 
  This source is only used to compile and install the package.
 }

unit TAChartLazarusPkg; 

interface

uses
  TASeries, TAGraph, TAChartUtils, TASeriesEditor, LazarusPackageIntf;

implementation

procedure Register; 
begin
  RegisterUnit('TAGraph', @TAGraph.Register); 
  RegisterUnit('TASeriesEditor', @TASeriesEditor.Register); 
end; 

initialization
  RegisterPackage('TAChartLazarusPkg', @Register); 
end.
