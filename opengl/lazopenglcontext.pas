{ Этот файл был автоматически создан Lazarus. Н�
  � редактировать!
  Исходный код используется только для комп�
    �ляции и установки пакета.
 }

unit lazopenglcontext;

interface

uses
  OpenGLContext, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('OpenGLContext',@OpenGLContext.Register);
end;

initialization
  RegisterPackage('LazOpenGLContext',@Register);
end.
