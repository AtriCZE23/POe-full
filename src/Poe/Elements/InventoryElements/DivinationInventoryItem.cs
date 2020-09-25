using SharpDX;

namespace PoeHUD.Poe.Elements
{
    public class DivinationInventoryItem : NormalInventoryItem
    {
        // Inventory Position in Essence Stash is always invalid.
        // Also, as items are fixed, so Inventory Position doesn't matter.
        public override int InventPosX => 0;
        public override int InventPosY => 0;

        public override RectangleF GetClientRect()
        {
            var tmp = Parent.GetClientRect();

            // div stash tab scrollbar element scroll value calculator
            var addr = this.Parent.Parent.Parent.Parent.Children[2].Address + 0xA64;
            float sub = M.ReadInt(addr) * (float)107.5;
            tmp.Y -= sub;

            return tmp;
        }
    }
}
