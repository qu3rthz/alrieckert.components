{  Ce fichier est automatiquement cr�� par Lazarus. Ne pas le modifier!
  Ce code source est utilis� seulement pour compiler et installer
  le paquet Printer4Lazarus 0.0.0.1.
 }

unit Printer4Lazarus; 

interface

uses
  PrintersDlgs, OSPrinters, LazarusPackageIntf; 

implementation

procedure Register; 
begin
  RegisterUnit('PrintersDlgs', @PrintersDlgs.Register); 
end; 

initialization
  RegisterPackage('Printer4Lazarus', @Register); 
end.
