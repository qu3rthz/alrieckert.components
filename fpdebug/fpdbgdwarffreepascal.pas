unit FpDbgDwarfFreePascal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FpDbgDwarfDataClasses, FpDbgDwarf, FpDbgInfo, DbgIntfBaseTypes;

type

  { TFpDwarfFreePascalSymbolClassMap }

  TFpDwarfFreePascalSymbolClassMap = class(TFpDwarfDefaultSymbolClassMap)
  public
    class function HandleCompUnit(ACU: TDwarfCompilationUnit): Boolean; override;
    //class function GetDwarfSymbolClass(ATag: Cardinal): TDbgDwarfSymbolBaseClass; override;
    class function CreateContext(AnAddress: TDBGPtr; ASymbol: TFpDbgSymbol;
      ADwarf: TDbgDwarf): TDbgInfoAddressContext; override;
    //class function CreateProcSymbol(ACompilationUnit: TDwarfCompilationUnit;
    //  AInfo: PDwarfAddressInfo; AAddress: TDbgPtr): TDbgDwarfSymbolBase; override;
  end;

  { TFpDwarfFreePascalAddressContext }

  TFpDwarfFreePascalAddressContext = class(TDbgDwarfInfoAddressContext)
  protected
    function FindLocalSymbol(const AName: String; PNameUpper, PNameLower: PChar;
      InfoEntry: TDwarfInformationEntry): TFpDbgSymbol; override;
  public
  end;

implementation

{ TFpDwarfFreePascalSymbolClassMap }

class function TFpDwarfFreePascalSymbolClassMap.HandleCompUnit(ACU: TDwarfCompilationUnit): Boolean;
var
  s: String;
begin
  s := LowerCase(ACU.Producer);
  Result := pos('free pascal', s) > 0;
end;

class function TFpDwarfFreePascalSymbolClassMap.CreateContext(AnAddress: TDbgPtr;
  ASymbol: TFpDbgSymbol; ADwarf: TDbgDwarf): TDbgInfoAddressContext;
begin
  Result := TFpDwarfFreePascalAddressContext.Create(AnAddress, ASymbol, ADwarf);
end;

{ TFpDwarfFreePascalAddressContext }

function TFpDwarfFreePascalAddressContext.FindLocalSymbol(const AName: String; PNameUpper,
  PNameLower: PChar; InfoEntry: TDwarfInformationEntry): TFpDbgSymbol;
const
  parentfp: string = 'parentfp';
var
  StartScopeIdx: Integer;
begin
  StartScopeIdx := InfoEntry.ScopeIndex;
  Result := inherited FindLocalSymbol(AName, PNameUpper, PNameLower, InfoEntry);
  if Result <> nil then
    exit;

  InfoEntry.ScopeIndex := StartScopeIdx;
  // TODO: cache
  if not InfoEntry.GoNamedChildEx(@parentfp, @parentfp) then
    exit;


  // check $parentfp
end;

initialization
  DwarfSymbolClassMapList.AddMap(TFpDwarfDefaultSymbolClassMap);

end.

