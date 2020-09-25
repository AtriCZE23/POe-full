﻿using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace PoeHUD.Hud.Settings
{
    public sealed class SortContractResolver : DefaultContractResolver
    {
        private const int MAX_PROPERTIES_PER_CONTRACT = 1000;

        protected override IList<JsonProperty> CreateProperties(Type type, MemberSerialization memberSerialization)
        {
            List<MemberInfo> members = GetSerializableMembers(type);
            if (members == null)
            {
                throw new JsonSerializationException("Null collection of serializable members returned.");
            }

            return members.Select(member => CreateProperty(member, memberSerialization))
                .Where(x => x != null)
                .OrderBy(x => MAX_PROPERTIES_PER_CONTRACT * GetTypeDepth(x.DeclaringType) + (x.Order ?? 0))
                .ToList();
        }

        private static int GetTypeDepth(Type type)
        {
            int depth = 0;
            while ((type = type.BaseType) != null)
            {
                depth++;
            }
            return depth;
        }
    }
}