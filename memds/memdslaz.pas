{ Этот файл был автоматически создан Lazarus. Н�
  � редактировать!
  Исходный код используется только для комп�
    �ляции и установки пакета.
 }

unit memdslaz;

interface

uses
  memds, frmSelectDataset, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('frmSelectDataset',@frmSelectDataset.Register);
end;

initialization
  RegisterPackage('MemDSLaz',@Register);
end.
