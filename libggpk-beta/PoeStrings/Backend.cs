﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Xml;
using System.Xml.Serialization;
using LibDat;
using LibGGPK;
using LibGGPK.Records;

namespace PoeStrings
{
    public class Backend
    {
        //private const string settingsPath = ".\\translation.xml";
        private readonly Action<string> outputFunc;
        public GrindingGearsPackageContainer content = new GrindingGearsPackageContainer();
        private string ggpkPath;
        private string binPath;
        private string settingsPath;


        /// <summary>
        /// Maps file names to FileRecord
        /// </summary>
        private Dictionary<string, FileRecord> fileRecordMap;
        public Dictionary<string, DatTranslation> AllDatTranslations { get; set; }

        public Backend(Action<string> outputFunc, string settingsPath)
        {
            this.settingsPath = settingsPath;
            this.outputFunc = outputFunc;
        }

        public void ReloadAllData(string ggpkPath)
        {
            this.ggpkPath = ggpkPath;
            content = new GrindingGearsPackageContainer();
            content.Read(ggpkPath, outputFunc);

            CollectTranslatableStrings();
            MergeUserTranslations();
        }

        public void ReloadAllData(string ggpkPath, string binPath)
        {
            this.ggpkPath = ggpkPath;
            this.binPath = binPath;
            content = new GrindingGearsPackageContainer();
            content.Read(ggpkPath, binPath, outputFunc);

            CollectTranslatableStrings();
            MergeUserTranslations();
        }

        /// <summary>
        /// Merges user translations with master list of transleatable strings and determiens if the user
        /// translation is already applied or is invalid (possibly due to a patch).
        /// </summary>
        private void MergeUserTranslations()
        {
            Dictionary<string, DatTranslation> userDatTranslations;
            try
            {
                userDatTranslations = ReadTranslationData();
            }
            catch (Exception ex)
            {
                OutputLine(string.Format(Settings.Strings["ReloadAllData_Failed"], ex.Message));
                return;
            }

            if (userDatTranslations == null)
            {
                return;
            }

            foreach (var userTranslation in userDatTranslations)
            {
                if (!AllDatTranslations.ContainsKey(userTranslation.Key))
                {
                    AllDatTranslations.Add(userTranslation.Key, new DatTranslation());
                }

                var currentDatTranslation = AllDatTranslations[userTranslation.Key];

                if (AllDatTranslations[userTranslation.Key].Translations == null)
                    continue;

                // Mapping of originalText -> Translation pairs to determine if the user translation is already applied, not yet applied, or no longer valid
                var translationsByOriginalHash = AllDatTranslations[userTranslation.Key].Translations.ToDictionary(k => k.OriginalText);

                foreach (var translation in userTranslation.Value.Translations)
                {
                    if (translationsByOriginalHash.ContainsKey(translation.OriginalText))
                    {
                        translation.Status = Translation.TranslationStatus.NeedToApply;

                        translationsByOriginalHash[translation.OriginalText].Status = translation.Status;
                        translationsByOriginalHash[translation.OriginalText].TranslatedText = translation.TranslatedText;
                        translationsByOriginalHash[translation.OriginalText].CurrentText = translation.OriginalText;
                    }
                    else if (translationsByOriginalHash.ContainsKey(translation.TranslatedText))
                    {
                        translation.Status = Translation.TranslationStatus.AlreadyApplied;

                        translationsByOriginalHash[translation.TranslatedText].Status = translation.Status;
                        translationsByOriginalHash[translation.TranslatedText].TranslatedText = translation.TranslatedText;
                        translationsByOriginalHash[translation.TranslatedText].CurrentText = translation.TranslatedText;
                        translationsByOriginalHash[translation.TranslatedText].OriginalText = translation.OriginalText;
                    }
                    else
                    {
                        translation.Status = Translation.TranslationStatus.Invalid;
                        currentDatTranslation.Translations.Add(translation);
                    }
                }
            }
        }

        /// <summary>
        /// Applies translations to content.ggpk
        /// </summary>
        public void ApplyTranslations()
        {
            var outputBuffer = new StringBuilder();

            foreach (var datTranslation in AllDatTranslations)
            {
                // Map of originalText -> Translation containing all translations to apply
                var translationsToApply = (from n in datTranslation.Value.Translations
                                                                       where n.Status == Translation.TranslationStatus.NeedToApply
                                                                       select n).ToDictionary(k => k.OriginalText);
                if (translationsToApply.Count == 0)
                {
                    continue;
                }

                // Record we will be translating with data from translationTable
                var datRecord = fileRecordMap[datTranslation.Value.DatName];

                // Raw bytes of the .dat file we will be translating
                var datBytes = datRecord.ReadFileContent(ggpkPath);

                // Dat parser for changing the actual strings
                var dc = new DatContainer(new MemoryStream(datBytes), datTranslation.Value.DatName);

                // Replace the actual strings
                var strings = dc.GetUserStrings();
                foreach (var currentDatString in strings)
                {
                    if (!translationsToApply.ContainsKey(currentDatString.Value))
                        continue;

                    // TODO skip already strings already procesed in this loops
                    var translationBeingApplied = translationsToApply[currentDatString.Value];
                    currentDatString.NewValue = translationBeingApplied.TranslatedText;

                    outputBuffer.AppendLine(string.Format(
                        Settings.Strings["ApplyTranslations_TextReplaced"],
                        translationBeingApplied.ShortNameCurrent,
                        translationBeingApplied.ShortNameTranslated));
                    translationBeingApplied.Status = Translation.TranslationStatus.AlreadyApplied;
                }

                // dc.SaveAsBytes() will return the new data for this .dat file after replacing the original strings with whatever's in 'NewData'
                datRecord.ReplaceContents(ggpkPath, dc.SaveAsBytes(), content);
            }

            if (outputBuffer.Length > 0)
            {
                Output(outputBuffer.ToString());
            }
        }

        /// <summary>
        /// Applies translations to content.ggpk
        /// </summary>
        public void ApplyTranslationsToFile()
        {
            StringBuilder outputBuffer = new StringBuilder();

            foreach (var datTranslation in AllDatTranslations)
            {
                if (datTranslation.Value.Translations == null)
                    continue;
                // Map of originalText -> Translation containing all translations to apply
                var translationsToApply = (from n in datTranslation.Value.Translations
                                                                       where n.Status == Translation.TranslationStatus.NeedToApply
                                                                       select n).ToDictionary(k => k.OriginalText);
                if (translationsToApply.Count == 0)
                {
                    continue;
                }

                // Record we will be translating with data from translationTable
                var datRecord = fileRecordMap[datTranslation.Value.DatName];

                // Raw bytes of the .dat file we will be translating
                var datBytes = datRecord.ReadFileContent(ggpkPath);

                // Dat parser for changing the actual strings
                var dc = new DatContainer(new MemoryStream(datBytes), datTranslation.Value.DatName);

                // Replace the actual strings
                var strings = dc.GetUserStrings();
                foreach (var currentDatString in strings)
                {
                    if (!translationsToApply.ContainsKey(currentDatString.Value))
                    {
                        continue;
                    }

                    var translationBeingApplied = translationsToApply[currentDatString.Value];
                    currentDatString.NewValue = translationBeingApplied.TranslatedText;

                    outputBuffer.AppendLine(string.Format(
                        Settings.Strings["ApplyTranslations_TextReplaced"], 
                        translationBeingApplied.ShortNameCurrent, 
                        translationBeingApplied.ShortNameTranslated));
                    translationBeingApplied.Status = Translation.TranslationStatus.AlreadyApplied;
                }

                string subPath = "Data";
                bool exists = System.IO.Directory.Exists(subPath);
                if (!exists)
                    System.IO.Directory.CreateDirectory(subPath);
                string patched = "Data/" + datTranslation.Value.DatName;
                dc.Save(patched);
            }

            if (outputBuffer.Length > 0)
            {
                Output(outputBuffer.ToString());
            }
        }

        /// <summary>
        /// Searches all of the /data/*.dat files in content.ggpk for user strings that can be translated. Also fills
        /// out 'fileRecordMap' with valid datName -> FileRecord mappings.
        /// </summary>
        private void CollectTranslatableStrings()
        {
            AllDatTranslations = new Dictionary<string, DatTranslation>();
            fileRecordMap = new Dictionary<string, FileRecord>();

            foreach (var recordOffset in content.RecordOffsets)
            {
                var record = recordOffset.Value as FileRecord;

                if (record == null || record.ContainingDirectory == null || record.DataLength == 12)
                    continue;

                if (record.ContainingDirectory.Name != Settings.Strings["Directory"])
                    continue;

                if (Path.GetExtension(record.Name) != ".dat" && Path.GetExtension(record.Name) != ".dat64")
                    continue;

                // Make sure parser for .dat type actually exists
                if (!RecordFactory.HasRecordInfo(record.Name))
                    continue;

                // We'll need this .dat FileRecord later on so we're storing it in a map of fileName -> FileRecord
                fileRecordMap.Add(record.Name, record);

                List<string> translatableStrings;

                try
                {
                    translatableStrings = GetTranslatableStringsFromDatFile(record);
                }
                catch (Exception ex)
                {
                    OutputLine(string.Format(Settings.Strings["CollectTranslatableStrings_FailedReading"], record.Name, ex.Message));
                    continue;
                }

                var newDatTranslation = new DatTranslation(record.Name);

                foreach (var str in translatableStrings)
                {
                    newDatTranslation.Translations.Add(new Translation(str));
                }


                if (translatableStrings.Count > 0)
                {
                    AllDatTranslations.Add(record.Name, newDatTranslation);
                }
            }
        }

        /// <summary>
        /// Gets a list of all translatable strings in specified record. Record must be a FileRecord of a valid dat file.
        /// </summary>
        /// <param name="record">Dat File Record to extract translatable strings from</param>
        /// <returns>List of translatable strings contained in specified dat file</returns>
        private List<string> GetTranslatableStringsFromDatFile(FileRecord record)
        {
            // Map of all strings that can be safely translated (not used as ID's, paths, etc) stored by their hash
            var resultList = new HashSet<string>();
            var datBytes = record.ReadFileContent(ggpkPath);
            using (var datStream = new MemoryStream(datBytes))
            {
                var dc = new DatContainer(datStream, record.Name);
                var strings = dc.GetUserStrings();
                foreach (var currentDatString in strings)
                {
                    resultList.Add(currentDatString.GetValueString());
                }
            }
            return resultList.ToList();
        }

        /// <summary>
        /// Saves all translations to file
        /// </summary>
        public void SaveTranslationData()
        {
            var debugTranslationCount = 0;

            var datTranslations = new List<DatTranslation>();
            var serializer = new XmlSerializer(datTranslations.GetType());
            using (var fs = new FileStream(settingsPath, FileMode.Create))
            {
                foreach (var datTranslationTable in AllDatTranslations)
                {
                    if (datTranslationTable.Value.Translations == null || datTranslationTable.Value.Translations.Count == 0)
                        continue;

                    var newDatTranslation = new DatTranslation()
                    {
                        DatName = datTranslationTable.Key,
                        Translations = (from n in datTranslationTable.Value.Translations
                                        where n.Status != Translation.TranslationStatus.Ignore
                                        select
                                            new Translation()
                                            {
                                                TranslatedText = n.TranslatedText.Replace(Environment.NewLine, "__BREAK__"),
                                                OriginalText = n.OriginalText.Replace(Environment.NewLine, "__BREAK__"),
                                            }).ToList()
                    };

                    if (newDatTranslation.Translations.Count > 0)
                    {
                        datTranslations.Add(newDatTranslation);
                        debugTranslationCount += newDatTranslation.Translations.Count;
                    }
                }

                serializer.Serialize(fs, datTranslations);
                OutputLine(String.Format(Settings.Strings["SaveTranslationData_Successful"], debugTranslationCount, settingsPath));
            }
        }

        /// <summary>
        /// Reads user translations from file
        /// </summary>
        /// <returns></returns>
        private Dictionary<string, DatTranslation> ReadTranslationData()
        {
            var debugTranslationCount = 0;

            var newUserTranslations = new Dictionary<string, DatTranslation>();

            var serializer = new XmlSerializer(typeof(List<DatTranslation>));
            var deserializedTranslations = (List<DatTranslation>)serializer.Deserialize(XmlReader.Create(settingsPath));

            foreach (var datTranslationTable in deserializedTranslations)
            {
                newUserTranslations.Add(datTranslationTable.DatName, datTranslationTable);

                foreach (var translation in datTranslationTable.Translations)
                {
                    ++debugTranslationCount;
                    translation.TranslatedText = translation.TranslatedText.Replace("__BREAK__", Environment.NewLine);
                    translation.OriginalText = translation.OriginalText.Replace("__BREAK__", Environment.NewLine);
                    translation.Status = Translation.TranslationStatus.Invalid;
                }
            }

            OutputLine(string.Format(Settings.Strings["ReadTranslationData_Successful"], debugTranslationCount));
            return newUserTranslations;
        }

        private void Output(string text)
        {
            if (outputFunc != null)
                outputFunc(text);
        }

        private void OutputLine(string text)
        {
            Output(text + Environment.NewLine);
        }
    }
}
