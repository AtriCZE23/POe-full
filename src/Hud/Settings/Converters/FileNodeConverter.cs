﻿using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;

namespace PoeHUD.Hud.Settings.Converters
{
    public class FileNodeConverter : CustomCreationConverter<FileNode>
    {
        public override bool CanWrite => true;
        public override bool CanRead => true;

        public override FileNode Create(Type objectType)
        {
            return string.Empty;
        }

        public override object ReadJson(JsonReader reader, Type objectType, object existingValue, JsonSerializer serializer)
        {
            return new FileNode(serializer.Deserialize<string>(reader));
        }

        public override void WriteJson(JsonWriter writer, object value, JsonSerializer serializer)
        {
            var fileNode = value as FileNode;
            if (fileNode != null) serializer.Serialize(writer, fileNode.Value);
        }
    }
}