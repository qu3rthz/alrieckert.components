unit jcfuiconsts;

{$mode objfpc}{$H+}

interface

resourcestring
  //Settings caption and error messages
  lisJCFFormatSettings = 'JCF Format Settings';
  lisTheSettingsFileDoesNotExist = 'The settings file "%s" does not exist.%s'+
    'The formatter will work better if it is configured to use a valid settings file';
  lisErrorWritingSettingsFileReadOnly = 'Error writing settings file: %s is read only';
  lisErrorWritingSettingsException = 'Error writing settings file %s:%s%s';
  lisNoSettingsFound = 'No settings found';

  //Format File settings tab
  lisFrFilesFileIsWritable = 'File is writable';
  lisFrFilesFormatFileIs = 'Format file is %s';
  lisFrFilesFileNotFound = 'File not found';
  lisFrFilesFileISReadOnly = 'File is read only';
  lisFrFilesDateFileWritten = 'Date file written: %s';
  lisFrFilesVersionThatWroteThisFile = 'Version that wrote this file: %s';
  lisFrFilesDescription = 'Description:';
  lisFrFilesFormatFile = 'Format File';

  //Obfuscate settings tab
  lisObfsObfuscate = 'Obfuscate';
  lisObfsObfuscateMode = '&Obfuscate mode';
  lisObfsObfuscateWordCaps = 'Obfuscate word &caps';
  lisObfsAllCapitals = 'ALL CAPITALS';
  lisObfsAllLowerCase = 'all lowercase';
  lisObfsMixedCase = 'Mixed Case';
  lisObfsLeaveAlone = 'Leave alone';
  lisObfsRemoveWhiteSpace = 'Remove &white space';
  lisObfsRemoveComments = 'Remove c&omments';
  lisObfsRemoveIndent = 'Remove &indent';
  lisObfsRebreakLines = 'Rebreak &lines';

  //Clarify tab
  lisClarifyClarify = 'Clarify';
  lisClarifyFileExtensionsToFormat = 'File extensions to format:';
  lisClarifyRunOnceOffs = 'Run once-offs';
  lisClarifyDoNotRun = 'Do &not run';
  lisClarifyDoRun = 'Do &run';
  lisClarifyRunOnlyThese = 'Run &only these';

  //Spaces tab
  lisSpacesSpaces = 'Spaces';
  lisSpacesFixSpacing = 'Fix &spacing';
  lisSpacesSpaceBeforeClassHeritage = 'Space before class &heritage';
  lisSpacesSpacesBeforeColonIn = 'Spaces &before colon in';
  lisSpacesVarDeclarations = '&Var declarations';
  lisSpacesConstDeclarations = 'C&onst declarations';
  lisSpacesProcedureParameters = '&Procedure parameters';
  lisSpacesFunctionReturnTypes = '&Function return types';
  lisSpacesClassVariables = '&Class variables';
  lisSpacesRecordFields = '&Record fields';
  lisSpacesCaseLAbel = 'Case l&abel';
  lisSpacesLabel = '&Label';
  lisSpacesInGeneric = 'In &generic';
  lisSpacesSpacesAroundOperators = 'Spaces around &operators';
  lisSpacesAlways = 'Always';
  lisSpacesLeaveAsIs = 'Leave as is';
  lisSpacesNever = 'Never';
  lisSpacesInsertSpaceBeforeBracket = '&Insert space before bracket';
  lisSpacesInFunctionDeclaration = 'In function &declaration';
  lisSpacesInFunctionCall = 'In function &call';
  lisSpacesBeforeInExpression = 'Before [ in expression';
  lisSpacesInsertSpaceInsideBrackets = 'Insert space inside brackets';
  lisSpacesAfterOpen = 'After open';
  lisSpacesBeforeEnd = 'Before end';
  lisSpacesMoveSpacesToBeforeColon = 'Move spaces to before colon';
  lisSpacesTabCharacters = '&Tab characters';
  lisSpacesTurnTabsToSpaces = 'Turn tabs to spaces';
  lisSpacesSpacesPerTab = 'Spaces per tab';
  lisSpacesTurnSpacesToTabs = 'Turn spaces to tabs';
  lisSpacesSpacesForTab = 'Spaces for tab';
  lisSpacesMaxSpacesInCode = '&Max spaces in code';

  //Indentation tab
  lisIndentIndentation = 'Indentation';
  lisIndentBlockIndentationSpaces = 'Block indentation spaces';
  lisIndentOptions = 'Options';
  lisIndentExtraIndentForBeginEnd = 'Extra indent for begin/end inside '
    +'procedures';
  lisIndentDifferentIndentForFirstLevel = 'Different indent for first level';
  lisIndentKeepSingleLineCommentsWithCodeInProcs = 'Keep single-line comments '
    +'with code in procedures';
  lisIndentKeepSingleLineCommentsWithCodeInGlobals = 'Keep single-line '
    +'comments with code in globals';
  lisIndentKeepSingleLineCommentsWithCodeInClassDefs = 'Keep single-line '
    +'comments with code in class definitions';
  lisIndentKeepSingleLineCommentsWithCodeElsewhere = 'Keep single-line '
    +'comments with code elsewhere';
  lisIndentExtraIndentForIfElseBlocks = 'Extra Indent for If...Else blocks';
  lisIndentExtraIndentForCaseElseBlocks = 'Extra Indent for Case...Else blocks';
  lisIndentIndentForProceduresInLibrary = 'Indent for procedures in library';
  lisIndentIndentForProcedureBody = 'Indent for procedure body';
  lisIndentIndentNestedTypes = 'Indent nested types';
  lisIndentIndentVarAndConstInClass = 'Indent var and const in class';

  //Blank lines tab
  lisBLBlankLines = 'Blank Lines';
  lisBLRemoveBlankLines = 'Remove blank lines';
  lisBLInProcedureVarSection = 'In procedure var section';
  lisBLAfterProcedureHeader = 'After procedure header';
  lisBLAtStartAndEndOfBeginEndBlock = 'At start and end of Begin...End block';
  lisBLMaxConsecutiveBlankLinesBeforeRemoval = 'Max consecutive blank lines '
    +'before removal';
  lisBLNumberOfReturnsAfterTheUnitsFinalEnd = 'Number of returns after the '
    +'unit''s final End.';
  lisBLRemoveConsecutiveBlankLines = 'Remove consecutive blank lines';
  lisBLMaxConsecutiveBlankLinesAnywhere = 'Max consecutive blank lines anywhere';
  lisBLLinesBeforeProcedure = 'Lines before procedure';

  //Align tab
  lisAlignAlign = 'Align';
  lisAlignInterfaceOnly = 'Interface Only';
  lisAlignWhatToAlign = 'What to Align';
  lisAlignAssign = 'Assign';
  lisAlignConst = 'Const';
  lisAlignVarDeclarations = 'Var declarations';
  lisAlignClassAndRecordFields = 'Class and record fields';
  lisAlignTypeDefs = 'Type defs';
  lisAlignComments = 'Comments';
  lisAlignMinColumn = 'Min Column';
  lisAlignMaxColumn = 'Max Column';
  lisAlignMaxVariance = 'Max Variance';
  lisAlignMaxVarianceInterface = 'Max Variance Interface';
  lisAlignMaxUnaligned = 'Max unaligned';

  //Line Breaking tab
  lisLBLineBreaking = 'Line Breaking';
  lisLBMaxLineLength = 'Max line length';
  lisLBBreakLinesThatAreLongerThanMaxLineLength = '&Break lines that are '
    +'longer than max line length';
  lisLBNever = '&Never';
  lisLBSometimesIfAGoodPlaceToBreakIsFound = '&Sometimes, if a good place to '
    +'break is found';
  lisLBUsuallyUnlessThereIsNoAcceptablePlaceToBreak = '&Usually, unless there '
    +'is no acceptable place to break';

  //Returns tab
  lisReturnsReturns = 'Returns';
  lisReturnsRemoveReturns = 'Remove returns';
  lisReturnsInMiscBadPlaces = 'In misc. bad places';
  lisReturnsInProperties = 'In properties';
  lisReturnsInProcedureDefinitions = 'In procedure definitions';
  lisReturnsInVariableDeclarations = 'In variable declarations';
  lisReturnsInExpressions = 'In expressions';
  lisReturnsInsertReturns = 'Insert returns';
  lisReturnsInMiscGoodPlaces = 'In misc. good places';
  lisReturnsOneUsesClauseItemPerLine = 'One uses clause item per line';
  lisReturnsAfterUses = 'After uses';
  lisReturnsReturnChars = 'Return chars';
  lisReturnsLeaveAsIs = 'Leave as is';
  lisReturnsConvertToCarriageReturn = 'Convert to Carriage Return (UNIX)';
  lisReturnsConvertToCarriageReturnLinefeed = 'Convert to Carriage Return + '
    +'Linefeed (DOS/Windows)';

  //Case Blocks tab
  lisCaseBlocksCaseBlocks = 'Case Blocks';
  lisCaseBlocksUseANewLineInCaseBlocksAt = 'Use a new line in Case blocks at:';
  lisCaseBlocksLabelWithBegin = 'Label with begin';
  lisCaseBlocksLabelWithoutBegin = 'Label without begin';
  lisCaseBlocksCaseWithBegin = 'Case with begin';
  lisCaseBlocksCaseWithoutBegin = 'Case without begin';
  lisCaseBlocksElseCaseWithBegin = 'Else case with begin';
  lisCaseBlocksElseCaseWithoutBegin = 'Else case without begin';
  lisCaseBlocksAlways = 'Always';
  lisCaseBlocksLeaveAsIs = 'Leave as is';
  lisCaseBlocksNever = 'Never';

  //Blocks tab
  lisBlocksBlocks = 'Blocks';
  lisBlocksUseANewLineInBlocksAt = 'Use a new line in blocks at:';
  lisBlocksBlockWithBegin = 'Block with begin';
  lisBlocksBlockWithoutBegin = 'Block without begin';
  lisBlocksBetweenElseAndIf = 'Between else and if';
  lisBlocksBetweenEndAndElse = 'Between end and else';
  lisBlocksElseBegin = 'Else begin';

  //Compiler Directives tab
  lisCDCompilerDirectives = 'Compiler Directives';
  lisCDUseANewLineBeforeCompilerDirectives = 'Use a new line before compiler '
    +'directives:';
  lisCDUsesClause = 'Uses clause';
  lisCDStatements = 'Statements';
  lisCDOtherPlaces = 'Other places';
  lisCDUseANewLineAfterCompilerDirectives = 'Use a new line after compiler '
    +'directives:';

implementation

end.
