﻿using System;
using SharpDX;

namespace PoeHUD.Poe.RemoteMemoryObjects
{
    public class ServerStashTab : RemoteMemoryObject
    {
        internal const int StructSize = 0x40;  
        private const int ColorOffset = 0x2c;

        public string Name => NativeStringReader.ReadString(Address + 0x8) + (RemoveOnly ? " (Remove-only)" : string.Empty);   
        public Color Color => new Color(M.ReadByte(Address + ColorOffset), M.ReadByte(Address + ColorOffset + 1), M.ReadByte(Address + ColorOffset + 2));//for aplpha + 3
        public InventoryTabPermissions MemberFlags => (InventoryTabPermissions)M.ReadUInt(Address + 0x3C);
        public InventoryTabPermissions OfficerFlags => (InventoryTabPermissions)M.ReadUInt(Address + 0x34);
        public InventoryTabType TabType => (InventoryTabType)M.ReadUInt(Address + 0x34);
        public ushort VisibleIndex => M.ReadUShort(Address + 0x38);
        //public ushort LinkedParentId => M.ReadUShort(Address + 0x26);
        public InventoryTabFlags Flags => (InventoryTabFlags)M.ReadByte(Address + 0x3D);
	    public bool RemoveOnly => (Flags & InventoryTabFlags.RemoveOnly) == InventoryTabFlags.RemoveOnly;
	    public bool IsHidden => (Flags & InventoryTabFlags.Hidden) == InventoryTabFlags.Hidden;

	    public override string ToString()
        {
            return $"{Name}{(RemoveOnly ? " (Remove-only)" : string.Empty)}, DisplayIndex: {VisibleIndex}, {TabType}";
        }

        [Flags]
        public enum InventoryTabPermissions : uint
        {
            Add = 2,
            None = 0,
            Remove = 4,
            View = 1
        }

        public enum InventoryTabType : uint
        {
            Currency = 3,
            Divination = 6,
            Essence = 8,
            Fragment = 9,
            Map = 5,
            Normal = 0,
            Premium = 1,
            Quad = 7,
            Todo2 = 2,
            Todo4 = 4
        }

        [Flags]
        public enum InventoryTabFlags : byte
        {
            Hidden = 0x80,
            MapSeries = 0x40,
            Premium = 4,
            Public = 0x20,
            RemoveOnly = 1,
            Unknown1 = 0x10,
            Unknown2 = 2,
            Unknown3 = 8
        }
    }
}