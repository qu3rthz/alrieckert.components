{ Этот файл был автоматически создан Lazarus. Н�
  � редактировать!
  Исходный код используется только для комп�
    �ляции и установки пакета.
 }

unit cgilazide;

interface

uses
  CGILazIDEIntf, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('CGILazIDEIntf',@CGILazIDEIntf.Register);
end;

initialization
  RegisterPackage('CGILazIDE',@Register);
end.
