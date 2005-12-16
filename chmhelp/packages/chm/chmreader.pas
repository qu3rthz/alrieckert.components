{ Copyright (C) <2005> <Andrew Haines> chmreader.pas

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}
{ This license will be changed to a modified LGPL if I get permission to change
  license of paslzx.pas to the modified LGPL that the FCL uses. - Andrew Haines
}
unit chmreader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLProc, chmbase, paslzx;
  
type

  TLZXResetTableArr = array of QWord;
  
  PContextItem = ^TContextItem;
  TContextItem = record
    Context: THelpContext;
    Url: String;
  end;
  
  TContextList = class(TList)
  public
    procedure AddContext(Context: THelpContext; Url: String);
    function GetURL(Context: THelpContext): String;
    procedure Clear; override;
  end;
  { TChmReader }

  TChmReader = class(TObject)
    fStream: TStream;
    fFreeStreamOnDestroy: Boolean;
    fChmHeader: TITSFHeader;
    fHeaderSuffix: TITSFHeaderSuffix;
    fDirectoryHeader: TITSPHeader;
    fDirectoryHeaderPos: Int64;
    fDirectoryHeaderLength: QWord;
    fDirectoryEntriesStartPos: Int64;
    fDirectoryEntries: array of TPMGListChunkEntry;
    fCachedEntry: TPMGListChunkEntry; //contains the last entry found by ObjectExists
    fDirectoryEntriesCount: LongWord;
    
    fDefaultPage: String;
    fIndexFile: String;
    fTOCFile: String;
    fTitle: String;
    fPreferedFont: String;
    fContextList: TContextList;
    fLocaleID: DWord;
  private
    procedure ReadHeader;
    procedure ReadCommonData;
    function GetChunkType(Stream: TMemoryStream; ChunkIndex: LongInt): TPMGchunktype;
    procedure LookupPMGLchunk(Stream: TMemoryStream; ChunkIndex: LongInt; out PMGLChunk: TPMGListChunk);
    function ReadPMGLchunkEntryFromStream(Stream: TMemoryStream; var PMGLEntry: TPMGListChunkEntry): Boolean;
    //procedure LookupPMGIchunk(var PMGLChunk: TPMGIndexChunk);
    procedure FillDirectoryEntries(StartCount: Integer);
    procedure GetSections(out Sections: TStringList);
    function GetBlockFromSection(SectionPrefix: String; StartPos: QWord; Length: QWord): TMemoryStream;
    function FindBlocksFromUnCompressedAddr(var ResetTableEntry: TPMGListChunkEntry;
       out CompressedSize: Int64; out UnCompressedSize: Int64; out LZXResetTable: TLZXResetTableArr): QWord;  // Returns the blocksize
  public
    constructor Create(AStream: TStream; FreeStreamOnDestroy: Boolean);
    destructor Destroy; override;
  public
    ChmLastError: LongInt;
    function IsValidFile: Boolean;
    procedure GetCompleteFileList(var Strings: TStrings);
    function ObjectExists(Name: String): QWord; // zero if no. otherwise it is the size of the object
                                                // NOTE directories will return zero size even if they exist
    function GetObject(Name: String): TMemoryStream; // YOU must Free the stream
    function GetContextUrl(Context: THelpContext): String;
    function HasContextList: Boolean;
    property DefaultPage: String read fDefaultPage;
    property IndexFile: String read fIndexFile;
    property TOCFile: String read fTOCFile;
    property Title: String read fTitle;
    property PreferedFont: String read fPreferedFont;
    property LocaleID: dword read fLocaleID;
  end;
  
//ErrorCodes
const
  ERR_NO_ERR = 0;
  ERR_STREAM_NOT_ASSIGNED = 1;
  ERR_NOT_SUPPORTED_VERSION = 2;
  ERR_NOT_VALID_FILE = 3;
  ERR_UNKNOWN_ERROR = 10;
  
  function ChmErrorToStr(Error: Integer): String;

implementation

function ChmErrorToStr(Error: Integer): String;
begin
  Result := '';
  case Error of
    ERR_STREAM_NOT_ASSIGNED    : Result := 'ERR_STREAM_NOT_ASSIGNED';
    ERR_NOT_SUPPORTED_VERSION  : Result := 'ERR_NOT_SUPPORTED_VERSION';
    ERR_NOT_VALID_FILE         : Result := 'ERR_NOT_VALID_FILE';
    ERR_UNKNOWN_ERROR          : Result := 'ERR_UNKNOWN_ERROR';
  end;
end;

{ TChmReader }

procedure TChmReader.ReadHeader;
var
fHeaderEntries: array [0..1] of TITSFHeaderEntry;
begin
  fStream.Position := 0;
  fStream.Read(fChmHeader,SizeOf(fChmHeader));

  // Fix endian issues
  {$IFDEF ENDIAN_BIG}
  fChmHeader.Version := LEtoN(fChmHeader.Version);
  fChmHeader.HeaderLength := LEtoN(fChmHeader.HeaderLength);
  //Unknown_1
  fChmHeader.TimeStamp := BEtoN(fChmHeader.TimeStamp);//bigendian
  fChmHeader.LanguageID := LEtoN(fChmHeader.LanguageID);
  //Guid1
  //Guid2
  {$ENDIF}
  
  if not IsValidFile then Exit;
  
  // Copy EntryData into memory
  fStream.Read(fHeaderEntries[0], SizeOf(fHeaderEntries));

  if fChmHeader.Version > 2 then
    fStream.Read(fHeaderSuffix.Offset, SizeOf(QWord));
  // otherwise this is set in fill directory entries
  
  fStream.Position := LEtoN(fHeaderEntries[1].PosFromZero);
  fDirectoryHeaderPos := LEtoN(fHeaderEntries[1].PosFromZero);
  fStream.Read(fDirectoryHeader, SizeOf(fDirectoryHeader));
  {$IFDEF ENDIAN_BIG}
  with fDirectoryHeader do begin
    Version := LEtoN(Version);
    DirHeaderLength := LEtoN(DirHeaderLength);
    //Unknown1
    ChunkSize := LEtoN(ChunkSize);
    Density := LEtoN(Density);
    IndexTreeDepth := LEtoN(IndexTreeDepth);
    IndexOfRootTrunk := LEtoN(IndexOfRootChunk);
    FirstPMGLChunk := LEtoN(FirstPMGLChunkIndex);
    LastPMGLChunk := LEtoN(LastPMGLChunkIndex);
    //Unknown2
    DirectoryChunkCount := LEtoN(DirectoryChunkCount);
    LanguageID := LEtoN(LanguageID);
    //GUID: TGuid;
    LengthAgain := LEtoN(LengthAgain);
  end;
  {$ENDIF}
  fDirectoryEntriesStartPos := fStream.Position;
  fDirectoryHeaderLength := LEtoN(fHeaderEntries[1].Length);
end;

procedure TChmReader.ReadCommonData;
   // A little helper proc to make reading a null terminated string easier
   function ReadString(const Stream: TStream): String;
   var
     buf: array[0..49] of char;
   begin
     Result := '';
     repeat
       Stream.Read(buf, 50);
       Result := Result + buf;
     until Pos(#0, buf) > -1;
   end;
   procedure ReadFromSystem;
   var
     //Version: DWord;
     EntryType: Word;
     EntryLength: Word;
     Data: array[0..255] of char;
     fSystem: TMemoryStream;
     Tmp: String;
   begin
     fSystem := TMemoryStream(GetObject('/#SYSTEM'));
     if fSystem = nil then begin
       exit;
     end;
     fSystem.Position := 0;
     if fSystem.Size < SizeOf(DWord) then begin
       fSystem.Free;
       Exit;
     end;
     {Version := }LEtoN(fSystem.ReadDWord);
     while fSystem.Position < fSystem.Size do begin
       EntryType := LEtoN(fSystem.ReadWord);
       EntryLength := LEtoN(fSystem.ReadWord);
       case EntryType of
         0: // Table of contents
         begin
           fSystem.Read(Data[0], EntryLength);
           Data[EntryLength] := #0;
           fTOCFile := '/'+Data;
         end;
         1: // Index File
         begin
           fSystem.Read(Data[0], EntryLength);
           Data[EntryLength] := #0;
           fIndexFile := '/'+Data;
         end;
         2: // DefaultPage
         begin
           fSystem.Read(Data[0], EntryLength);
           Data[EntryLength] := #0;
           fDefaultPage := '/'+Data;
         end;
         3: // Title of chm
         begin
           fSystem.Read(Data[0], EntryLength);
           Data[EntryLength] := #0;
           fTitle := Data;
         end;
         4: // Locale ID
         begin
           fLocaleID := LEtoN(fSystem.ReadDWord);
           fSystem.Position := (fSystem.Position + EntryLength) - SizeOf(DWord);
         end;
         6: // chm file name. use this to get the index an toc name
         begin
           fSystem.Read(Data[0], EntryLength);
           Data[EntryLength] := #0;
           if (fIndexFile = '') then begin
             Tmp := '/'+Data+'.hhk';
             if (ObjectExists(Tmp) > 0) then begin
               fIndexFile := Tmp;
             end
           end;
           if (fTOCFile = '') then begin
             Tmp := '/'+Data+'.hhc';
             if (ObjectExists(Tmp) > 0) then begin
               fTOCFile := Tmp;
             end;
           end;
         end;
         16: // Prefered font
         begin
           fSystem.Read(Data[0], EntryLength);
           Data[EntryLength] := #0;
           fPreferedFont := Data;
         end;
       else
         // Skip entries we are not interested in
         fSystem.Position := fSystem.Position + EntryLength;
       end;
     end;
     fSystem.Free;
   end;
   procedure ReadFromWindows;
   var
     fWindows,
     fStrings: TMemoryStream;
     EntryCount,
     EntrySize: DWord;
     EntryStart: Int64;
     StrPosition: DWord;
     X: Integer;
     OffSet: Int64;
   begin
     fWindows := TMemoryStream(GetObject('/#WINDOWS'));
     if fWindows = nil then begin
       exit;
     end;
     fStrings := TMemoryStream(GetObject('/#STRINGS'));
     if fStrings = nil then begin
       if fWindows <> nil then fWindows.Free;
       Exit;
     end;
     fWindows.Position := 0;
     if (fWindows.Size = 0) or (fStrings.Size = 0) then begin
       fWindows.Free;
       fStrings.Free;
       Exit;
     end;
     EntryCount := LEtoN(fWindows.ReadDWord);
     EntrySize := LEtoN(fWindows.ReadDWord);
     OffSet := fWindows.Position;
     for X := 0 to EntryCount -1 do begin
       EntryStart := OffSet + (X*EntrySize);
       if fTitle = '' then begin
         fWindows.Position := EntryStart + $14;
         StrPosition := LEtoN(fWindows.ReadDWord);
         fStrings.Position := StrPosition;
         fTitle := '/'+ReadString(fStrings);
       end;
       if fTOCFile = '' then begin
         fWindows.Position := EntryStart + $60;
         StrPosition := LEtoN(fWindows.ReadDWord);
         fStrings.Position := StrPosition;
         fTOCFile := '/'+ReadString(fStrings);
       end;
       if fIndexFile = '' then begin
         fWindows.Position := EntryStart + $64;
         StrPosition := LEtoN(fWindows.ReadDWord);
         fStrings.Position := StrPosition;
         fIndexFile := '/'+ReadString(fStrings);
       end;
       if fDefaultPage = '' then begin
         fWindows.Position := EntryStart + $68;
         StrPosition := LEtoN(fWindows.ReadDWord);
         fStrings.Position := StrPosition;
         fDefaultPage := '/'+ReadString(fStrings);
       end;
     end;
   end;
   procedure ReadContextIds;
   var
     fIVB,
     fStrings: TStream;
     Str: String;
     Value: DWord;
     OffSet: DWord;
     //TotalSize: DWord;
   begin
     fIVB := GetObject('/#IBV');
     if fIVB = nil then Exit;
     fStrings := GetObject('/#STRINGS');
     if fStrings = nil then begin
       fIVB.Free;
       Exit;
     end;
     fIVB.Position := 0;
     {TotalSize := }LEtoN(fIVB.ReadDWord);
     while fIVB.Position < fIVB.Size do begin
       Value := LEtoN(fIVB.ReadDWord);
       OffSet := LEtoN(fIVB.ReadDWord);
       fStrings.Position := Offset;
       Str := '/'+ReadString(fStrings);
       fContextList.AddContext(Value, Str);
     end;
   end;
begin
   ReadFromSystem;
   ReadFromWindows;
   ReadContextIds;
   //WriteLn('TOC=',fTocfile);
   //WriteLn('DefaultPage=',fDefaultPage);
end;

function TChmReader.GetChunkType(Stream: TMemoryStream; ChunkIndex: LongInt): TPMGchunktype;
var
  Sig: array[0..3] of char;
begin
  Result := ctUnknown;
  Stream.Position := fDirectoryEntriesStartPos + (fDirectoryHeader.ChunkSize * ChunkIndex);

  Stream.Read(Sig, 4);
  if Sig = 'PMGL' then Result := ctPMGL
  else if Sig = 'PMGI' then Result := ctPMGI;
end;

procedure TChmReader.LookupPMGLchunk(Stream: TMemoryStream; ChunkIndex: LongInt; out PMGLChunk: TPMGListChunk);
begin
  Stream.Position := fDirectoryEntriesStartPos + (fDirectoryHeader.ChunkSize * ChunkIndex);
  Stream.Read(PMGLChunk, SizeOf(PMGLChunk));
  {$IFDEF ENDIAN_BIG}
  with PMGLChunk do begin
    UnusedSpace := LEtoN(UnusedSpace);
    //Unknown1
    PreviousChunkIndex := LEtoN(PreviousChunkIndex);
    NextChunkIndex := LEtoN(NextChunkIndex);
  end;
  {$ENDIF}
end;

function TChmReader.ReadPMGLchunkEntryFromStream(Stream: TMemoryStream; var PMGLEntry: TPMGListChunkEntry): Boolean;
var
Buf: array [0..1123] of char;
NameLength: LongInt;
begin
  Result := False;
  //Stream.Position := fDirectoryEntriesStartPos + (fDirectoryHeader.ChunkSize * ChunkIndex);
  NameLength := LongInt(GetCompressedInteger(Stream));
  Stream.Read(buf, NameLength);

  buf[NameLength] := #0;
  PMGLEntry.Name := buf;
  PMGLEntry.ContentSection := LongWord(GetCompressedInteger(Stream));
  PMGLEntry.ContentOffset := GetCompressedInteger(Stream);
  PMGLEntry.DecompressedLength := GetCompressedInteger(Stream);
  if NameLength = 0 then Exit; // failed GetCompressedInteger sanity check
  Result := True;
end;

constructor TChmReader.Create(AStream: TStream; FreeStreamOnDestroy: Boolean);
begin
  fStream := AStream;
  fFreeStreamOnDestroy := FreeStreamOnDestroy;
  ReadHeader;
  if not IsValidFile then Exit;
  FillDirectoryEntries(1000); // the default size of the array
  fContextList := TContextList.Create;
  ReadCommonData;
end;

destructor TChmReader.Destroy;
begin
  SetLength(fDirectoryEntries, 0);
  if fFreeStreamOnDestroy then FreeAndNil(fStream);
  fContextList.Free;
  inherited Destroy;
end;

function TChmReader.IsValidFile: Boolean;
begin
  if (fStream = nil) then ChmLastError := ERR_STREAM_NOT_ASSIGNED
  else if (fChmHeader.ITSFsig <> 'ITSF') then ChmLastError := ERR_NOT_VALID_FILE
  else if (fChmHeader.Version <> 2) and (fChmHeader.Version <> 3) then
    ChmLastError := ERR_NOT_SUPPORTED_VERSION;
  Result := ChmLastError = ERR_NO_ERR;
end;

procedure TChmReader.GetCompleteFileList(var Strings: TStrings);
var
X : LongInt;
begin
  Strings.Clear;
  for X := 0 to fDirectoryEntriesCount-1 do begin
    Strings.Add(fDirectoryEntries[X].Name);
  end;
end;

function TChmReader.ObjectExists(Name: String): QWord;
var
X: Integer;
begin
  Result := 0;
  NAme := Lowercase(Name);
  if Name = LowerCase(fCachedEntry.Name) then begin
    Result := fCachedEntry.DecompressedLength;
    Exit;
  end;
  if (Length(Name) > 0) and (Name[1] = ':') then begin
    for X := fDirectoryEntriesCount-1 downto 0 do begin //Start at the end
      if LowerCase(fDirectoryEntries[X].Name) = Name then begin
        fCachedEntry := fDirectoryEntries[X];
        Result := fCachedEntry.DecompressedLength;
        Exit;
      end;
    end;
    exit;
  end;
  //else
  for X := 0 to fDirectoryEntriesCount-1 do begin //start at the beginning
    if LowerCase(fDirectoryEntries[X].Name) = Name then begin
      fCachedEntry := fDirectoryEntries[X];
      Result := fCachedEntry.DecompressedLength;
      Exit;
    end;
  end;
end;

function TChmReader.GetObject(Name: String): TMemoryStream;
var
  SectionNames: TStringList;
  Entry: TPMGListChunkEntry;
  SectionName: String;
begin
  Result := nil;
  if ObjectExists(Name) = 0 then Exit;
  Entry := fCachedEntry;
  if Entry.ContentSection = 0 then begin
    Result := TMemoryStream.Create;
    fStream.Position := fHeaderSuffix.Offset+ Entry.ContentOffset;
    Result.CopyFrom(fStream, fCachedEntry.DecompressedLength);
  end
  else begin // we have to get it from ::DataSpace/Storage/[MSCompressed,Uncompressed]/ControlData
    GetSections(SectionNames);
    FmtStr(SectionName, '::DataSpace/Storage/%s/',[SectionNames[Entry.ContentSection-1]]);
    Result := GetBlockFromSection(SectionName, Entry.ContentOffset, Entry.DecompressedLength);
    SectionNames.Free;
  end;
  if Result <> nil then Result.Position := 0;
end;

function TChmReader.GetContextUrl(Context: THelpContext): String;
begin
  // will get '' if context not found
 Result := fContextList.GetURL(Context);
end;

function TChmReader.HasContextList: Boolean;
begin
  Result := fContextList.Count > 0;
end;

procedure TChmReader.FillDirectoryEntries(StartCount: Integer);
var
 ChunkStart: QWord;
 PMGLChunk: TPMGListChunk;
 X: Integer;
 DirEntrySize: LongWord;
 // for speed we load this section into a tmemorystream
 EntriesBuffer: TMemoryStream;
 CopySize: Int64;
begin
  EntriesBuffer := TMemoryStream.Create;
  CopySize := fDirectoryEntriesStartPos + (fDirectoryHeader.ChunkSize * fDirectoryHeader.DirectoryChunkCount);
  fStream.Position := 0;
  EntriesBuffer.CopyFrom(fStream, CopySize);
  SetLength(fDirectoryEntries, StartCount);
  DirEntrySize := StartCount;
  for X := 0 to fDirectoryHeader.DirectoryChunkCount-1 do begin
     if GetChunkType(EntriesBuffer, X) = ctPMGL then begin
       ChunkStart := EntriesBuffer.Position-4;

       LookupPMGLchunk(EntriesBuffer, X, PMGLChunk);
       while EntriesBuffer.Position < ChunkStart + fDirectoryHeader.ChunkSize - PMGLChunk.UnusedSpace do begin
          if fDirectoryEntriesCount >= DirEntrySize-1 then begin
            Inc(DirEntrySize, 1000);
            SetLength(fDirectoryEntries, DirEntrySize);
          end;
          if ReadPMGLchunkEntryFromStream(EntriesBuffer, fDirectoryEntries[fDirectoryEntriesCount])
          then Inc(fDirectoryEntriesCount);
       end;
     end;
  end;
  EntriesBuffer.Free;
  if fChmHeader.Version = 2 then
    fHeaderSuffix.Offset := ChunkStart + fDirectoryHeader.ChunkSize;
  SetLength(fDirectoryEntries,fDirectoryEntriesCount);
end;

procedure TChmReader.GetSections(out Sections: TStringList);
var
  Stream: TStream;
  EntryCount: Word;
  X: Integer;
  WString: array [0..32] of WideChar;
  StrLength: Word;
begin
  Sections := TStringList.Create;
  Stream := GetObject('::DataSpace/NameList');

  if Stream = nil then exit;
  
  Stream.Position := 2;
  EntryCount := LEtoN(Stream.ReadWord);
  for X := 0 to EntryCount -1 do begin
    StrLength := LEtoN(Stream.ReadWord);
    // are widestrings endian specfic?
    Stream.Read(WString, SizeOf(WideChar)*(StrLength+1)); // the strings are stored null terminated
    Sections.Add(WString);
  end;
  // the sections are sorted alphabetically, this way section indexes will jive
  Sections.Sort;
  Stream.Free;
end;

function TChmReader.GetBlockFromSection(SectionPrefix: String; StartPos: QWord;
  Length: QWord): TMemoryStream;
var
  Compressed: Boolean;
  Sig: Array [0..3] of char;
  CompressionVersion: LongWord;
  CompressedSize: Int64;
  UnCompressedSize: Int64;
  //LZXResetInterval: LongWord;
  //LZXWindowSize: LongWord;
  //LZXCacheSize: LongWord;
  ResetTableEntry: TPMGListChunkEntry;
  ResetTable: TLZXResetTableArr;
  WriteCount: QWord;
  BlockWriteLength: QWord;
  WriteStart: LongWord;
  ReadCount:LongInt;
  LZXState: PLZXState;
  InBuf: PByte;
  OutBuf: PByte;
  BlockSize: QWord;
  X: Integer;
  FirstBlock, LastBlock: LongInt;
  ResultCode: LongInt;
begin
  // okay now the fun stuff ;)
  Result := nil;
  Compressed := ObjectExists(SectionPrefix+'Transform/{7FC28940-9D31-11D0-9B27-00A0C91E9C7C}/InstanceData/ResetTable')>0;
  // the easy method
  if Not(Compressed) then begin
    if ObjectExists(SectionPrefix+'Content') > 0 then begin
      Result := TMemoryStream.Create;
      fStream.Position := fHeaderSuffix.Offset + fCachedEntry.ContentOffset + StartPos;
      Result.CopyFrom(fStream, Length);
    end;
    Exit;
  end
  else
    ResetTableEntry := fCachedEntry;

  // First make sure that it is a compression we can read
  if ObjectExists(SectionPrefix+'ControlData') > 0 then begin
    fStream.Position := fHeaderSuffix.Offset + fCachedEntry.ContentOffset + 4;
    fStream.Read(Sig, 4);
    if Sig <> 'LZXC' then Exit;
    CompressionVersion := LEtoN(fStream.ReadDWord);
    if CompressionVersion > 2 then exit;
    {LZXResetInterval := }LEtoN(fStream.ReadDWord);
    {LZXWindowSize := }LEtoN(fStream.ReadDWord);
    {LZXCacheSize := }LEtoN(fStream.ReadDWord);


    BlockSize := FindBlocksFromUnCompressedAddr(ResetTableEntry, CompressedSize, UnCompressedSize, ResetTable);
    if StartPos > 0 then
      FirstBlock := StartPos div BlockSize
    else
      FirstBlock := 0;
    LastBlock := (StartPos+Length) div BlockSize;

    if ObjectExists(SectionPrefix+'Content') = 0 then exit;
    Result := TMemoryStream.Create;
    Result.Size := Length;
    InBuf := AllocMem(BlockSize);
    OutBuf := GetMem(BlockSize);
    // First Init a PLZXState
    LZXState := LZXinit(16);
    if LZXState = nil then begin
      Exit;
    end;
    // if FirstBlock is odd (1,3,5,7 etc) we have to read the even block before it first.
    if (FirstBlock <> 0) and (FirstBlock mod 2 > 0) then begin
      fStream.Position := fHeaderSuffix.Offset + fCachedEntry.ContentOffset + (ResetTable[FirstBLock-1]);
      ReadCount := ResetTable[FirstBlock] - ResetTable[FirstBlock-1];
      BlockWriteLength:=BlockSize;
      fStream.Read(InBuf^, ReadCount);
      ResultCode := LZXdecompress(LZXState, InBuf, OutBuf, ReadCount, LongInt(BlockWriteLength));
    end;
    // now start the actual decompression loop
    for X := FirstBlock to LastBlock do begin
      fStream.Position := fHeaderSuffix.Offset + fCachedEntry.ContentOffset + (ResetTable[X]);

      if X = FirstBLock then
        WriteStart := StartPos - (X*BlockSize)
      else
        WriteStart := 0;

      if X = High(ResetTable) then
        ReadCount := CompressedSize - ResetTable[X]
      else
        ReadCount := ResetTable[X+1] - ResetTable[X];

      BlockWriteLength := BlockSize;
      
      if FirstBlock = LastBlock then begin
        WriteCount := Length;
      end
      else if X = LastBlock then
        WriteCount := (StartPos+Length) - (X*BlockSize)
      else WriteCount := BlockSize - WriteStart;

      ReadCount := fStream.Read(InBuf^, ReadCount);
      ResultCode := LZXdecompress(LZXState, InBuf, OutBuf, ReadCount, LongInt(BlockWriteLength));

      //now write the decompressed data to the stream
      if ResultCode = DECR_OK then begin
        Result.Write(OutBuf[WriteStart], Int64(WriteCount));
      end
      else begin
        //WriteLn('Decompress FAILED with error code: ', ResultCode);
        Result.Free;
        Result := Nil;
        FreeMem(InBuf);
        FreeMem(OutBuf);
        SetLength(ResetTable,0);
        LZXteardown(LZXState);
        Exit;
      end;
      
      // if the next block is an even numbered block we have to reset the decompressor state
      if (X < LastBlock) and (X mod 2 > 0) then LZXreset(LZXState);

    end;
    Freemem(InBuf);
    FreeMem(OutBuf);
    SetLength(ResetTable,0);
    LZXteardown(LZXState);
  end;
end;

function TChmReader.FindBlocksFromUnCompressedAddr(var ResetTableEntry: TPMGListChunkEntry;
  out CompressedSize: Int64; out UnCompressedSize: Int64; out LZXResetTable: TLZXResetTableArr): QWord;
var
  BlockCount: LongWord;
  X: Integer;
begin
  Result := 0;
  fStream.Position := fHeaderSuffix.Offset + ResetTableEntry.ContentOffset;
  fStream.ReadDWord;
  BlockCount := LEtoN(fStream.ReadDWord);
  fStream.ReadDWord;
  fStream.ReadDWord; // TableHeaderSize;
  fStream.Read(UnCompressedSize, SizeOf(QWord));
  UnCompressedSize := LEtoN(UnCompressedSize);
  fStream.Read(CompressedSize, SizeOf(QWord));
  CompressedSize := LEtoN(CompressedSize);
  fStream.Read(Result, SizeOf(QWord)); // block size
  Result := LEtoN(Result);

  // now we are located at the first block index

  SetLength(LZXResetTable, BlockCount);
  fStream.Read(LZXResetTable[0], SizeOf(QWord)*BlockCount);


end;

{ TContextList }

procedure TContextList.AddContext(Context: THelpContext; Url: String);
var
  ContextItem: PContextItem;
begin
  New(ContextItem);
  Add(ContextItem);
  ContextItem^.Context := Context;
  ContextItem^.Url := Url;
end;

function TContextList.GetURL(Context: THelpContext): String;
var
  X: Integer;
begin
  Result := '';
  for X := 0 to Count-1 do begin
    if PContextItem(Get(X))^.Context = Context then begin
      Result := PContextItem(Get(X))^.Url;
      Exit;
    end;
  end;

end;

procedure TContextList.Clear;
var
  X: Integer;
begin
  for X := Count-1 downto 0 do begin
    Dispose(PContextItem(Get(X)));
    Delete(X);
  end;
end;


end.

