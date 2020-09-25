using System;
using PoeHUD.Models;

namespace PoeHUD.Controllers
{
    public class AreaController
    {
        private readonly GameController _gController;

        public AreaController(GameController gameController)
        {
            _gController = gameController;
        }

        public AreaInstance CurrentArea { get; private set; }
        [Obsolete("Use OnAreaChange event in plugin to avoid memory leek")]
        public event Action<AreaController> OnAreaChange;
        public event Action<AreaController> AreaChange;

        public void RefreshState()
        {
            if (!_gController.InGame)
                return;

            _gController.Cache.UpdateCache();
            var ingameData = _gController.Game.IngameState.Data;
            var areaTemplate = ingameData.CurrentArea;
            var curAreaHash = ingameData.CurrentAreaHash;

            if (CurrentArea != null && curAreaHash == CurrentArea.Hash)
                return;

            CurrentArea = new AreaInstance(areaTemplate, curAreaHash, ingameData.CurrentAreaLevel);
            AreaChange?.Invoke(this);
            OnAreaChange?.Invoke(this);
        }
    }
}
