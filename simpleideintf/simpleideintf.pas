{ Diese Datei wurde automatisch von Lazarus erzeugt. Sie darf nicht bearbeitet werden!
Dieser Quelltext dient nur dem �bersetzen und Installieren des Packages.
 }

unit SimpleIDEIntf; 

interface

uses
  SimpleIDE, LazarusPackageIntf; 

implementation

procedure Register; 
begin
end; 

initialization
  RegisterPackage('SimpleIDEIntf', @Register); 
end.
