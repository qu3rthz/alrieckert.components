{ Этот файл был автоматически создан Lazarus. Н�
  � редактировать!
  Исходный код используется только для комп�
    �ляции и установки пакета.
 }

unit dbflaz;

interface

uses
  RegisterDBF, Dbf, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('RegisterDBF',@RegisterDBF.Register);
end;

initialization
  RegisterPackage('DBFLaz',@Register);
end.
