{ Этот файл был автоматически создан Lazarus. Н�
  � редактировать!
  Исходный код используется только для комп�
    �ляции и установки пакета.
 }

unit cgilaz;

interface

uses
  cgiModules, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('cgiLaz',@Register);
end.
