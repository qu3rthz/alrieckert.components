{ Этот файл был автоматически создан Lazarus. Н�
  � редактировать!
  Исходный код используется только для комп�
    �ляции и установки пакета.
 }

unit runtimetypeinfocontrols;

interface

uses
  RTTICtrls, RTTIGrids, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('RTTICtrls',@RTTICtrls.Register);
  RegisterUnit('RTTIGrids',@RTTIGrids.Register);
end;

initialization
  RegisterPackage('RunTimeTypeInfoControls',@Register);
end.
