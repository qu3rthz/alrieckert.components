{
 ---------------------------------------------------------------------------
 FpPascalParser.pas  -  Native Freepascal debugger - Parse pascal expressions
 ---------------------------------------------------------------------------

 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************
}
unit FpPascalParser;

{$mode objfpc}{$H+}

interface

uses
  Classes, sysutils, math, LCLProc, FpDbgDwarf, LazLoggerBase;

type

  TFpGDBMIExpressionPart = class;
  TFpGDBMIExpressionPartContainer = class;
  TFpGDBMIExpressionPartBracket = class;
  TFpGDBMIExpressionPartOperator = class;

  TFpGDBMIExpressionPartClass = class of TFpGDBMIExpressionPart;
  TFpGDBMIExpressionPartBracketClass = class of TFpGDBMIExpressionPartBracket;

  { TFpGDBMIExpression }

  TFpGDBMIExpression = class
  private
    FError: String;
    FTextExpression: String;
    FExpressionPart: TFpGDBMIExpressionPart;
    FValid: Boolean;
    procedure Parse;
    procedure SetError(AMsg: String);
    function PosFromPChar(APChar: PChar): Integer;
  protected
    property ExpressionPart: TFpGDBMIExpressionPart read FExpressionPart;
  public
    constructor Create(ATextExpression: String);
    destructor Destroy; override;
    function DebugDump: String;
    property Error: String read FError;
    property Valid: Boolean read FValid;
  end;


  { TFpGDBMIExpressionPart }

  TFpGDBMIExpressionPart = class
  private
    FEndChar: PChar;
    FParent: TFpGDBMIExpressionPartContainer;
    FStartChar: PChar;
    FExpression: TFpGDBMIExpression;
    function GetSurroundingBracket: TFpGDBMIExpressionPartBracket;
    function GetTopParent: TFpGDBMIExpressionPart;
    procedure SetEndChar(AValue: PChar);
    procedure SetParent(AValue: TFpGDBMIExpressionPartContainer);
    procedure SetStartChar(AValue: PChar);
    function  GetText(AMaxLen: Integer=0): String;
    procedure SetError(AMsg: String = '');
    procedure SetError(APart: TFpGDBMIExpressionPart; AMsg: String = '');
  protected
    function DebugText(AIndent: String): String; virtual; // Self desc only
    function DebugDump(AIndent: String): String; virtual;
  protected
    procedure Init; virtual;
    Procedure ReplaceInParent(AReplacement: TFpGDBMIExpressionPart);
    procedure DoHandleEndOfExpression; virtual;

    function IsValidNextPart(APart: TFpGDBMIExpressionPart): Boolean; virtual;
    function IsValidAfterPart(APrevPart: TFpGDBMIExpressionPart): Boolean; virtual;
    function MaybeHandlePrevPart(APrevPart: TFpGDBMIExpressionPart;
                                 var AResult: TFpGDBMIExpressionPart): Boolean; virtual;
    function FindLeftSideOperandByPrecedence(AnOperator: TFpGDBMIExpressionPartOperator): TFpGDBMIExpressionPart; virtual;
    function CanHaveOperatorAsNext: Boolean; virtual; // True
  public
    constructor Create(AExpression: TFpGDBMIExpression; AStartChar: PChar; AnEndChar: PChar = nil);
    function  HandleNextPart(APart: TFpGDBMIExpressionPart): TFpGDBMIExpressionPart; virtual;
    procedure HandleEndOfExpression; virtual;

    property StartChar: PChar read FStartChar write SetStartChar;
    property EndChar: PChar read FEndChar write SetEndChar;
    property Parent: TFpGDBMIExpressionPartContainer read FParent write SetParent;
    property TopParent: TFpGDBMIExpressionPart read GetTopParent; // or self
    property SurroundingBracket: TFpGDBMIExpressionPartBracket read GetSurroundingBracket; // incl self
  end;

  { TFpGDBMIExpressionPartContainer }

  TFpGDBMIExpressionPartContainer = class(TFpGDBMIExpressionPart)
  private
    FList: TList;
    function GetCount: Integer;
    function GetItems(AIndex: Integer): TFpGDBMIExpressionPart;
    function GetLastItem: TFpGDBMIExpressionPart;
    procedure SetItems(AIndex: Integer; AValue: TFpGDBMIExpressionPart);
    procedure SetLastItem(AValue: TFpGDBMIExpressionPart);
  protected
    procedure Init; override;
    function DebugDump(AIndent: String): String; override;
  public
    destructor Destroy; override;
    function Add(APart: TFpGDBMIExpressionPart): Integer;
    function IndexOf(APart: TFpGDBMIExpressionPart): Integer;
    procedure Clear;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TFpGDBMIExpressionPart read GetItems write SetItems;
    property LastItem: TFpGDBMIExpressionPart read GetLastItem write SetLastItem;
  end;

  { TFpGDBMIExpressionPartIdentifer }

  TFpGDBMIExpressionPartIdentifer = class(TFpGDBMIExpressionPartContainer)
  public
  end;


  { TFpGDBMIExpressionPartBracket }

  TFpGDBMIExpressionPartBracket = class(TFpGDBMIExpressionPartContainer)
  private
    FIsClosed: boolean;
    FIsClosing: boolean;
  protected
    procedure Init; override;
    procedure DoHandleEndOfExpression; override;
    function CanHaveOperatorAsNext: Boolean; override;
  public
    procedure CloseBracket;
    function HandleNextPart(APart: TFpGDBMIExpressionPart): TFpGDBMIExpressionPart; override;
    procedure HandleEndOfExpression; override;
    property IsClosed: boolean read FIsClosed;
  end;

  { TFpGDBMIExpressionPartRoundBracket }
  TFpGDBMIExpressionPartRoundBracket = class(TFpGDBMIExpressionPartBracket)
  end;

  { TFpGDBMIExpressionPartOperator }

  TFpGDBMIExpressionPartOperator = class(TFpGDBMIExpressionPartContainer)
  private
    FPrecedence: Integer;
  protected
    function DebugText(AIndent: String): String; override;
    function CanHaveOperatorAsNext: Boolean; override;
    function FindLeftSideOperandByPrecedence(AnOperator: TFpGDBMIExpressionPartOperator): TFpGDBMIExpressionPart; override;
    function HasAllOperands: Boolean; virtual; abstract;
    function MaybeAddLeftOperand(APrevPart: TFpGDBMIExpressionPart;
      var AResult: TFpGDBMIExpressionPart): Boolean;
    procedure DoHandleEndOfExpression; override;
  public
    function HandleNextPart(APart: TFpGDBMIExpressionPart): TFpGDBMIExpressionPart; override;
    property Precedence: Integer read FPrecedence;
  end;

  { TFpGDBMIExpressionPartUnaryOperator }

  TFpGDBMIExpressionPartUnaryOperator = class(TFpGDBMIExpressionPartOperator)
  protected
    function HasAllOperands: Boolean; override;
  public
  end;

  { TFpGDBMIExpressionPartBinaryOperator }

  TFpGDBMIExpressionPartBinaryOperator = class(TFpGDBMIExpressionPartOperator)
  protected
    function HasAllOperands: Boolean; override;
    function IsValidAfterPart(APrevPart: TFpGDBMIExpressionPart): Boolean; override;
  public
    function MaybeHandlePrevPart(APrevPart: TFpGDBMIExpressionPart;
      var AResult: TFpGDBMIExpressionPart): Boolean; override;
  end;

  { TFpGDBMIExpressionPartOperatorAddressOf }

  TFpGDBMIExpressionPartOperatorAddressOf = class(TFpGDBMIExpressionPartUnaryOperator)  // @
  protected
    procedure Init; override;
  end;

  { TFpGDBMIExpressionPartOperatorMakeRef }

  TFpGDBMIExpressionPartOperatorMakeRef = class(TFpGDBMIExpressionPartUnaryOperator)  // ^TTYpe
  protected
    procedure Init; override;
  end;

  { TFpGDBMIExpressionPartOperatorDeRef }

  TFpGDBMIExpressionPartOperatorDeRef = class(TFpGDBMIExpressionPartUnaryOperator)  // ptrval^
  protected
    procedure Init; override;
    function MaybeHandlePrevPart(APrevPart: TFpGDBMIExpressionPart;
      var AResult: TFpGDBMIExpressionPart): Boolean; override;
    function FindLeftSideOperandByPrecedence(AnOperator: TFpGDBMIExpressionPartOperator): TFpGDBMIExpressionPart;
      override;
    // IsValidAfterPart: same as binary op
    function IsValidAfterPart(APrevPart: TFpGDBMIExpressionPart): Boolean; override;
  end;

  { TFpGDBMIExpressionPartOperatorUnaryPlusMinus }

  TFpGDBMIExpressionPartOperatorUnaryPlusMinus = class(TFpGDBMIExpressionPartUnaryOperator)  // + -
  // Unary + -
  protected
    procedure Init; override;
  end;

  { TFpGDBMIExpressionPartOperatorPlusMinus }

  TFpGDBMIExpressionPartOperatorPlusMinus = class(TFpGDBMIExpressionPartBinaryOperator)  // + -
  // Binary + -
  protected
    procedure Init; override;
  end;

  { TFpGDBMIExpressionPartOperatorMulDiv }

  TFpGDBMIExpressionPartOperatorMulDiv = class(TFpGDBMIExpressionPartBinaryOperator)    // * /
  protected
    procedure Init; override;
  end;

  { TFpGDBMIExpressionPartOperatorMemberOf }

  TFpGDBMIExpressionPartOperatorMemberOf = class(TFpGDBMIExpressionPartBinaryOperator)    // struct.member
  protected
    procedure Init; override;
  end;

implementation

{ TFpGDBMIExpressionPartOperatorMemberOf }

procedure TFpGDBMIExpressionPartOperatorMemberOf.Init;
begin
  FPrecedence := 0;
  inherited Init;
end;

{ TFpGDBMIExpressionPartOperatorMakeRef }

procedure TFpGDBMIExpressionPartOperatorMakeRef.Init;
begin
  FPrecedence := 1;
  inherited Init;
end;

{ TFpGDBMIExpressionPartOperatorDeRef }

procedure TFpGDBMIExpressionPartOperatorDeRef.Init;
begin
  FPrecedence := 1;
  inherited Init;
end;

function TFpGDBMIExpressionPartOperatorDeRef.MaybeHandlePrevPart(APrevPart: TFpGDBMIExpressionPart;
  var AResult: TFpGDBMIExpressionPart): Boolean;
begin
  Result := MaybeAddLeftOperand(APrevPart, AResult);
end;

function TFpGDBMIExpressionPartOperatorDeRef.FindLeftSideOperandByPrecedence(AnOperator: TFpGDBMIExpressionPartOperator): TFpGDBMIExpressionPart;
begin
  Result := Self;
end;

function TFpGDBMIExpressionPartOperatorDeRef.IsValidAfterPart(APrevPart: TFpGDBMIExpressionPart): Boolean;
begin
  Result := inherited IsValidAfterPart(APrevPart);
  if not Result then
    exit;

  Result := APrevPart.CanHaveOperatorAsNext;

  // BinaryOperator...
  //   foo
  //   Identifer
  // "Identifer" can hane a binary-op next. But it must be applied to the parent.
  // So it is not valid here.
  // If new operator has a higher precedence, it go down to the child again and replace it
  if (APrevPart.Parent <> nil) and (APrevPart.Parent is TFpGDBMIExpressionPartOperator) then
    Result := False;
end;

{ TFpGDBMIExpressionPartRoundBracket }

procedure TFpGDBMIExpressionPartBracket.Init;
begin
  inherited Init;
  FIsClosed := False;
  FIsClosing := False;
end;

procedure TFpGDBMIExpressionPartBracket.DoHandleEndOfExpression;
begin
  if not IsClosed then begin
    SetError('Bracket not closed');
    exit;
  end;
  inherited DoHandleEndOfExpression;
end;

function TFpGDBMIExpressionPartBracket.CanHaveOperatorAsNext: Boolean;
begin
  Result := IsClosed;
end;

procedure TFpGDBMIExpressionPartBracket.CloseBracket;
begin
  FIsClosing := True;
  if LastItem <> nil then
    LastItem.HandleEndOfExpression;
  FIsClosing := False;
  FIsClosed := True;
end;

function TFpGDBMIExpressionPartBracket.HandleNextPart(APart: TFpGDBMIExpressionPart): TFpGDBMIExpressionPart;
begin
  if IsClosed then begin
    Result := inherited HandleNextPart(APart);
    exit;
  end;

  Result := Self;
  if Count > 0 then begin
    SetError('To many expressions');
    exit;
  end;

  Result := APart;
  Add(APart);
end;

procedure TFpGDBMIExpressionPartBracket.HandleEndOfExpression;
begin
  if not FIsClosing then
    inherited HandleEndOfExpression;
end;

{ TFpGDBMIExpressionPartOperatorUnaryPlusMinus }

procedure TFpGDBMIExpressionPartOperatorUnaryPlusMinus.Init;
begin
  FPrecedence := 1;
  inherited Init;
end;

{ TFpGDBMIExpression }

procedure TFpGDBMIExpression.Parse;
var
  CurPtr, EndPtr, TokenEndPtr: PChar;
  CurPart, NewPart: TFpGDBMIExpressionPart;

  procedure AddPart(AClass: TFpGDBMIExpressionPartClass);
  begin
    NewPart := AClass.Create(Self, CurPtr, TokenEndPtr-1);
  end;

  procedure AddPlusMinus;
  begin
    if (CurPart = nil) or (not CurPart.CanHaveOperatorAsNext)
    then AddPart(TFpGDBMIExpressionPartOperatorUnaryPlusMinus)
    else AddPart(TFpGDBMIExpressionPartOperatorPlusMinus);
  end;

  procedure AddConstChar;
  begin
  end;

  procedure AddConstNumber;
  begin
  end;

  procedure AddIdentifier;
  begin
    while TokenEndPtr^ in ['a'..'z', 'A'..'Z', '_', '0'..'9'] do
      inc(TokenEndPtr);
    // TODO: Check functions not, and, in, as, is ...
    NewPart := TFpGDBMIExpressionPartIdentifer.Create(Self, CurPtr, TokenEndPtr-1);
  end;

  procedure HandleDot;
  begin
    while TokenEndPtr^ = '.' do
      inc(TokenEndPtr);
    case TokenEndPtr - CurPtr of
      1: AddPart(TFpGDBMIExpressionPartOperatorMemberOf);
      //2: ; // ".."
      else SetError('Failed parsing ...');
    end;
  end;

  procedure AddRefOperator;
  begin
    if (CurPart = nil) or (not CurPart.CanHaveOperatorAsNext)
    then AddPart(TFpGDBMIExpressionPartOperatorMakeRef)
    else AddPart(TFpGDBMIExpressionPartOperatorDeRef);
  end;

  procedure CloseBracket(ABracketClass: TFpGDBMIExpressionPartBracketClass);
  begin
    NewPart := CurPart.SurroundingBracket;
    if NewPart = nil then begin
      SetError('Closing bracket found without opening')
    end
    else
    if not (NewPart is ABracketClass) then begin
      SetError('Mismatch bracket')
    end
    else begin
      TFpGDBMIExpressionPartBracket(NewPart).CloseBracket;
      CurPart := nil;
    end;
  end;

begin
  if FTextExpression = '' then
    exit;
  CurPtr := @FTextExpression[1];
  EndPtr := CurPtr + length(FTextExpression);
  CurPart := nil;

  While (CurPtr < EndPtr) and FValid do begin
    if CurPtr^ in [' ', #9, #10, #13] then begin
      while (CurPtr^ in [' ', #9, #10, #13]) and (CurPtr < EndPtr) do
        Inc(CurPtr);
      continue;
    end;

    NewPart := nil;
    TokenEndPtr := CurPtr + 1;
    case CurPtr^ of
      '@' :      AddPart(TFpGDBMIExpressionPartOperatorAddressOf);
      '^':       AddRefOperator;
      '.':       HandleDot;
      '+', '-' : AddPlusMinus;
      '*', '/' : AddPart(TFpGDBMIExpressionPartOperatorMulDiv);
      '(':       AddPart(TFpGDBMIExpressionPartRoundBracket);
      ')':       CloseBracket(TFpGDBMIExpressionPartRoundBracket);
      //'[': ;
      //'''':     AddConstChar;
      //'0'..'9',
      //'$', '%': AddConstNumber;
      'a'..'z',
      'A'..'Z', '_': AddIdentifier;
      else begin
          SetError(Format('Unexpected char ''%0:s'' at pos %1:s', [CurPtr^, PosFromPChar(CurPtr)])); // error
          break;
        end;
    end;
    if not FValid then
      break;
    assert(NewPart <> nil);

    if CurPart = nil
    then CurPart := NewPart
    else CurPart := CurPart.HandleNextPart(NewPart);

    CurPtr :=  TokenEndPtr;
  end; // While CurPtr < EndPtr do begin



  if CurPart <> nil then begin
    CurPart.HandleEndOfExpression;
    CurPart := CurPart.TopParent;
  end
  else
  if Valid then
    SetError('No Expression');

  FExpressionPart := CurPart;
end;

procedure TFpGDBMIExpression.SetError(AMsg: String);
begin
  FValid := False;
  FError := AMsg;
end;

function TFpGDBMIExpression.PosFromPChar(APChar: PChar): Integer;
begin
  Result := APChar - @FTextExpression[1] + 1;
end;

constructor TFpGDBMIExpression.Create(ATextExpression: String);
begin
  FTextExpression := ATextExpression;
  FValid := True;
  Parse;
end;

destructor TFpGDBMIExpression.Destroy;
begin
  FreeAndNil(FExpressionPart);
  inherited Destroy;
end;

function TFpGDBMIExpression.DebugDump: String;
begin
  Result := 'TFpGDBMIExpression: ' + FTextExpression + LineEnding +
            'Valid: ' + dbgs(FValid) + '   Error: "' + FError + '"'+ LineEnding
            ;
  if FExpressionPart <> nil then
    Result := Result + FExpressionPart.DebugDump('  ');
end;

{ TFpGDBMIExpressionPartContainer }

function TFpGDBMIExpressionPartContainer.GetItems(AIndex: Integer): TFpGDBMIExpressionPart;
begin
  Result := TFpGDBMIExpressionPart(FList[AIndex]);
end;

function TFpGDBMIExpressionPartContainer.GetLastItem: TFpGDBMIExpressionPart;
begin
  if Count > 0 then
    Result := Items[Count - 1]
  else
    Result := nil;
end;

procedure TFpGDBMIExpressionPartContainer.SetItems(AIndex: Integer;
  AValue: TFpGDBMIExpressionPart);
begin
  AValue.Parent := Self;
  FList[AIndex] := AValue;
end;

procedure TFpGDBMIExpressionPartContainer.SetLastItem(AValue: TFpGDBMIExpressionPart);
begin
  assert(Count >0);
  Items[Count-1] := AValue;
end;

procedure TFpGDBMIExpressionPartContainer.Init;
begin
  FList := TList.Create;
  inherited Init;
end;

function TFpGDBMIExpressionPartContainer.DebugDump(AIndent: String): String;
var
  i: Integer;
begin
  Result := inherited DebugDump(AIndent);
  for i := 0 to Count - 1 do
    Result := Result + Items[i].DebugDump(AIndent+'  ');
end;

function TFpGDBMIExpressionPartContainer.GetCount: Integer;
begin
  Result := FList.Count;
end;

destructor TFpGDBMIExpressionPartContainer.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited Destroy;
end;

function TFpGDBMIExpressionPartContainer.Add(APart: TFpGDBMIExpressionPart): Integer;
begin
  APart.Parent := Self;
  Result := FList.Add(APart);
end;

function TFpGDBMIExpressionPartContainer.IndexOf(APart: TFpGDBMIExpressionPart): Integer;
begin
  Result := Count - 1;
  while (Result >= 0) and (Items[Result] <> APart) do
    dec(Result);
end;

procedure TFpGDBMIExpressionPartContainer.Clear;
begin
  while Count > 0 do begin
    Items[0].Free;
    FList.Delete(0);
  end;
end;

{ TFpGDBMIExpressionPart }

procedure TFpGDBMIExpressionPart.SetEndChar(AValue: PChar);
begin
  if FEndChar = AValue then Exit;
  FEndChar := AValue;
end;

function TFpGDBMIExpressionPart.GetTopParent: TFpGDBMIExpressionPart;
begin
  Result := Self;
  while Result.Parent <> nil do
    Result := Result.Parent;
end;

function TFpGDBMIExpressionPart.GetSurroundingBracket: TFpGDBMIExpressionPartBracket;
var
  tmp: TFpGDBMIExpressionPart;
begin
  Result := nil;
  tmp := Self;
  while (tmp <> nil) and not(tmp is TFpGDBMIExpressionPartBracket) do
    tmp := tmp.Parent;
  if tmp <> nil then
    Result := TFpGDBMIExpressionPartBracket(tmp);
end;

procedure TFpGDBMIExpressionPart.SetParent(AValue: TFpGDBMIExpressionPartContainer);
var
  Old: TFpGDBMIExpressionPart;
begin
  if FParent = AValue then Exit;
  Old := FParent;
  FParent := AValue;
end;

procedure TFpGDBMIExpressionPart.SetStartChar(AValue: PChar);
begin
  if FStartChar = AValue then Exit;
  FStartChar := AValue;
end;

function TFpGDBMIExpressionPart.GetText(AMaxLen: Integer): String;
var
  Len: Integer;
begin
  if FEndChar <> nil
  then Len := FEndChar - FStartChar + 1
  else Len := min(AMaxLen, 10);
  if (AMaxLen > 0) and (Len > AMaxLen) then
    Len := AMaxLen;
  Result := Copy(FStartChar, 1, Len);
end;

procedure TFpGDBMIExpressionPart.SetError(AMsg: String);
begin
  if AMsg = '' then
    AMsg := 'Invalid Expression';
  FExpression.SetError(Format('%0:s at %1:d: "%2:s"', [AMsg, FExpression.PosFromPChar(FStartChar), GetText(20)]));
end;

procedure TFpGDBMIExpressionPart.SetError(APart: TFpGDBMIExpressionPart; AMsg: String);
begin
  if APart <> nil
  then APart.SetError(AMsg)
  else Self.SetError(AMsg);
end;

procedure TFpGDBMIExpressionPart.Init;
begin
  //
end;

procedure TFpGDBMIExpressionPart.ReplaceInParent(AReplacement: TFpGDBMIExpressionPart);
var
  i: Integer;
begin
  if Parent = nil then exit;
  i := Parent.IndexOf(Self);
  Assert(i >= 0);
  Parent.Items[i] := AReplacement;
  Parent := nil;
end;

procedure TFpGDBMIExpressionPart.DoHandleEndOfExpression;
begin
  //
end;

function TFpGDBMIExpressionPart.IsValidNextPart(APart: TFpGDBMIExpressionPart): Boolean;
begin
  Result := APart.IsValidAfterPart(Self);
end;

function TFpGDBMIExpressionPart.IsValidAfterPart(APrevPart: TFpGDBMIExpressionPart): Boolean;
begin
  Result := True;
end;

function TFpGDBMIExpressionPart.MaybeHandlePrevPart(APrevPart: TFpGDBMIExpressionPart;
  var AResult: TFpGDBMIExpressionPart): Boolean;
begin
  Result := False;
end;

function TFpGDBMIExpressionPart.FindLeftSideOperandByPrecedence(AnOperator: TFpGDBMIExpressionPartOperator): TFpGDBMIExpressionPart;
begin
  Result := Self;
end;

function TFpGDBMIExpressionPart.CanHaveOperatorAsNext: Boolean;
begin
  Result := True;
end;

function TFpGDBMIExpressionPart.DebugText(AIndent: String): String;
begin
  Result := Format('%s%s at %d: "%s"',
                   [AIndent, ClassName, FExpression.PosFromPChar(FStartChar), GetText])
                   + LineEnding;
end;

function TFpGDBMIExpressionPart.DebugDump(AIndent: String): String;
begin
  Result := DebugText(AIndent);
end;

constructor TFpGDBMIExpressionPart.Create(AExpression: TFpGDBMIExpression; AStartChar: PChar;
  AnEndChar: PChar);
begin
  FExpression := AExpression;
  FStartChar := AStartChar;
  FEndChar := AnEndChar;
  Init;
end;

function TFpGDBMIExpressionPart.HandleNextPart(APart: TFpGDBMIExpressionPart): TFpGDBMIExpressionPart;
begin
  Result := APart;
  if APart.MaybeHandlePrevPart(Self, Result) then
    exit;

  if Parent <> nil then begin
    Result := Parent.HandleNextPart(APart);
    exit;
  end;

  SetError(APart, 'Unexpected ');
  APart.Free;
  Result := Self;
end;

procedure TFpGDBMIExpressionPart.HandleEndOfExpression;
begin
  DoHandleEndOfExpression;
  if Parent <> nil then
    Parent.HandleEndOfExpression;
end;

{ TFpGDBMIExpressionPartOperator }

function TFpGDBMIExpressionPartOperator.DebugText(AIndent: String): String;
begin
  Result := inherited DebugText(AIndent);
  while Result[Length(Result)] in [#10, #13] do SetLength(Result, Length(Result)-1);
  Result := Result + ' Precedence:' + dbgs(FPrecedence) +
    LineEnding;
end;

function TFpGDBMIExpressionPartOperator.CanHaveOperatorAsNext: Boolean;
begin
  Result := HasAllOperands and LastItem.CanHaveOperatorAsNext;
end;

function TFpGDBMIExpressionPartOperator.FindLeftSideOperandByPrecedence(AnOperator: TFpGDBMIExpressionPartOperator): TFpGDBMIExpressionPart;
begin
  Result := Self;

  if (not HasAllOperands) or (LastItem = nil) then begin
    Result := nil;
    exit
  end;

  // precedence: 1 = highest
  if Precedence > AnOperator.Precedence then
    Result := LastItem.FindLeftSideOperandByPrecedence(AnOperator);
end;

function TFpGDBMIExpressionPartOperator.MaybeAddLeftOperand(APrevPart: TFpGDBMIExpressionPart;
  var AResult: TFpGDBMIExpressionPart): Boolean;
var
  ALeftSide: TFpGDBMIExpressionPart;
begin
  Result := APrevPart.IsValidNextPart(Self);
  if not Result then
    exit;

  AResult := Self;
  if (Count > 0) or // Previous already set
     (not APrevPart.CanHaveOperatorAsNext) // can not have 2 operators follow each other
  then begin
    SetError(APrevPart, 'Can not apply operator '+GetText+': ');
    APrevPart.Free;
    exit;
  end;

  ALeftSide := APrevPart.FindLeftSideOperandByPrecedence(Self);
  if ALeftSide = nil then begin
    SetError(Self, 'Internal parser error for operator '+GetText+': ');
    APrevPart.Free;
    exit;
  end;

  ALeftSide.ReplaceInParent(Self);
  Add(ALeftSide);
end;

procedure TFpGDBMIExpressionPartOperator.DoHandleEndOfExpression;
begin
  if not HasAllOperands then
    SetError(Self, 'Not enough operands')
  else
    inherited DoHandleEndOfExpression;
end;

function TFpGDBMIExpressionPartOperator.HandleNextPart(APart: TFpGDBMIExpressionPart): TFpGDBMIExpressionPart;
begin
  Result := Self;
  if HasAllOperands then begin
    Result := inherited HandleNextPart(APart);
    exit;
  end;
  if not IsValidNextPart(APart) then begin
    SetError(APart, 'Not possible after Operator '+GetText+': ');
    APart.Free;
    exit;
  end;

  Add(APart);
  Result := APart;
end;

{ TFpGDBMIExpressionPartUnaryOperator }

function TFpGDBMIExpressionPartUnaryOperator.HasAllOperands: Boolean;
begin
  Result := Count = 1;
end;

{ TFpGDBMIExpressionPartBinaryOperator }

function TFpGDBMIExpressionPartBinaryOperator.HasAllOperands: Boolean;
begin
  Result := Count = 2;
end;

function TFpGDBMIExpressionPartBinaryOperator.IsValidAfterPart(APrevPart: TFpGDBMIExpressionPart): Boolean;
begin
  Result := inherited IsValidAfterPart(APrevPart);
  if not Result then
    exit;

  Result := APrevPart.CanHaveOperatorAsNext;

  // BinaryOperator...
  //   foo
  //   Identifer
  // "Identifer" can hane a binary-op next. But it must be applied to the parent.
  // So it is not valid here.
  // If new operator has a higher precedence, it go down to the child again and replace it
  if (APrevPart.Parent <> nil) and (APrevPart.Parent is TFpGDBMIExpressionPartOperator) then
    Result := False;
end;

function TFpGDBMIExpressionPartBinaryOperator.MaybeHandlePrevPart(APrevPart: TFpGDBMIExpressionPart;
  var AResult: TFpGDBMIExpressionPart): Boolean;
begin
  Result := MaybeAddLeftOperand(APrevPart, AResult);
end;

{ TFpGDBMIExpressionPartOperatorAddressOf }

procedure TFpGDBMIExpressionPartOperatorAddressOf.Init;
begin
  FPrecedence := 1; // highest
  inherited Init;
end;

{ TFpGDBMIExpressionPartOperatorPlusMinus }

procedure TFpGDBMIExpressionPartOperatorPlusMinus.Init;
begin
  FPrecedence := 3;
  inherited Init;
end;

{ TFpGDBMIExpressionPartOperatorMulDiv }

procedure TFpGDBMIExpressionPartOperatorMulDiv.Init;
begin
  FPrecedence := 2;
  inherited Init;
end;

end.

