unit pocheckerconsts;

{$mode objfpc}{$H+}

interface

Uses Controls;

resourcestring
  //Main form
  rsPoChecker = 'PO File Checker';
  sSelectBasicTests = 'Select &Basic';
  sSelectAllTests = 'Select &All';
  sUnselectAllTests = '&Unselect All';
  sGUIPoFileCheckingTool = 'GUI Po-file checking tool';
  sSelectTestTypes = 'Select test types';
  sOpenAPoFile = '&Open a po-file';
  sRunSelectedTests = '&Run Selected Tests';
  sCannotFindMaster = 'Cannot find master po file:' + LineEnding + '%s' + LineEnding + 'for selected file' + LineEnding + '%s';
  sNotAProperFileName = 'Selected filename' + LineEnding + '%s' + LineEnding + 'does not seem to be a proper name for a po-file';
  sErrorOnCreate = 'Error creating an instance of TPoFamily:' + LineEnding + '%s';
  sErrorOnCleanup = 'An unrecoverable error occurred' + LineEnding + '%s' + LineEnding + 'Please close the program';

  sTotalErrors = 'Total errors found: %d';
  sTotalWarnings = 'Total warnings found: %d';
  sNoErrorsFound = 'No errors found';
  sCurrentTest = 'Current Test:';
  sCurrentPoFile = 'Current po-file:';
  sNoTestSelected = 'There are no tests selected.';

  //Result form
  sSaveError = 'Error saving file:' + LineEnding + '%s';
  sSaveCaption = 'Save to file';
  sResults = 'Results';
  sCopyCaption = 'Copy to clipboard';
  sShowStatGraph = 'Show statistics graph';

  //Graphical summary form
  sGrapStatFormCaption = 'Graphical summary';
  sTranslated = 'Translated';
  sUntranslated = 'Untranslated';
  sFuzzy = 'Fuzzy';
  sStatHint = '%3d Translated (%3.1f%%)' + LineEnding +
              '%3d UnTranslated (%3.1f%%)' + LineEnding +
              '%3d Fuzzy (%3.1f%%)';
  sOpenFile = 'Open file %s in Ide Editor?';
  SOpenFail = 'Unable to open file %s';

  //PoFamiles
  sOriginal = 'Original';
  sTranslation = 'Translation';
  sErrorsByTest = 'Errors / warnings reported by %s for:';
  sTranslationStatistics = 'Translation statistics per language:';
  sCheckNumberOfItems = 'Check number of items';
  sCheckForIncompatibleFormatArguments = 'Check for incompatible format '
    +'arguments';
  sCheckMissingIdentifiers = 'Check missing identifiers';
  sCheckForMismatchesInUntranslatedStrings = 'Check for mismatches in '
    +'untranslated strings';
  sCheckForDuplicateUntranslatedValues = 'Check for duplicate untranslated '
    +'values';
  sCheckStatistics = 'Check percentage of (un)translated and fuzzy strings';
  sFindAllTranslatedPoFiles = 'Find all translated po-files';
  sIgnoreFuzzyTranslations = 'Ignore translated strings marked as "fuzzy"';
  sIncompatibleFormatArgs = '[Line: %d] Incompatible and/or invalid format() arguments for:' ;

  sNrErrorsFound = 'Found %d errors.';
  sNrWarningsFound = 'Found %d warnings.';
  sLineInFileName = '[Line %d] in %s:';
  sIdentifierNotFoundIn = 'Identifier [%s] not found in %s';
  sMissingMasterIdentifier = 'Identifier [%s] found in %s, but it does not exist in %s';
  sLineNr = '[Line: %d]';
  sNoteTranslationIsFuzzy = 'Note: translation is fuzzy';


  sNrOfItemsMisMatch = 'Mismatch in number of items for master and child';
  sNrOfItemsMismatchD = '%s: %d items';

  sDuplicateOriginals = 'The (untranslated) value "%s" is used for more than 1 entry:';

  sDuplicateLineNrWithValue = '[Line %d] %s';
  sPercTranslated = '%s: %4.1f%% translated strings.';
  sPercUntranslated = '%s: %4.1f%% untranslated strings.';
  sPercFuzzy = '%s: %4.1f%% fuzzy strings.';

const
  mrOpenEditorFile = mrNone+100;

implementation

end.

