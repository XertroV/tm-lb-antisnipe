void Main() {
    MLHook::InjectManialinkToPlayground(PageUID, LBANTISNIPE_SCRIPT_TXT, true);
    startnew(WatchMap);
}

const string PageUID = "LBAntiSnipe";

void OnDestroyed() { _Unload(); }
void OnDisabled() { _Unload(); }
void _Unload() {
    trace('_Unload, unloading hooks and removing injected ML');
    MLHook::RemoveInjectedMLFromPlayground(PageUID);
}

string lastMapUid;

void WatchMap() {
    while (true) {
        yield();
        if (lastMapUid != CurrentMap()) {
            lastMapUid = CurrentMap();
            startnew(OnMapChange);
        }
    }
}

string CurrentMap() {
    auto map = GetApp().RootMap;
    if (map is null) return "";
    return map.MapInfo.MapUid;
}

void OnMapChange() {
    if (lastMapUid.Length == 0) return;
    sleep(1000);
    CurrentlyEnabled = false;
    auto gameMode = cast<CTrackManiaNetworkServerInfo>(GetApp().Network.ServerInfo).CurGameModeStr;
    bool isSolo = gameMode.EndsWith("_Local");
    if (isSolo && S_EnableDefaultInSolo) {
        CurrentlyEnabled = true;
    }
    UpdateMLCurrentlyEnabled();
}

void UpdateMLCurrentlyEnabled() {
    if (CurrentlyEnabled) {
        SendEnableMsg();
        if (S_ShowNotifOnToggle) Notify("Activating...");
    } else {
        SendDisableMsg();
        if (S_ShowNotifOnToggle) Notify("Deactivating...");
    }
}

void SendEnableMsg() {
    MLHook::Queue_MessageManialinkPlayground(PageUID, {"Enable"});
}

void SendDisableMsg() {
    MLHook::Queue_MessageManialinkPlayground(PageUID, {"Disable"});
}

void RenderMenu() {
    if (UI::MenuItem("\\$f22" + Icons::Ban + Icons::Crosshairs + "\\$z LB AntiSnipe", "", CurrentlyEnabled)) {
        CurrentlyEnabled = !CurrentlyEnabled;
        UpdateMLCurrentlyEnabled();
    }
}

bool CurrentlyEnabled = false;

void RenderMenuMain() {
    if (!S_ShowQuickToggleMenubar) return;

    auto inPg = GetApp().CurrentPlayground !is null;

    UI::BeginDisabled(!inPg);

	bool wasClicked = UI::MenuItem("LB AntiSnipe", "", CurrentlyEnabled);
    if (wasClicked) {
        CurrentlyEnabled = !CurrentlyEnabled;
        UpdateMLCurrentlyEnabled();
    }

    UI::EndDisabled();
}


[Setting category="LB AntiSnipe" name="Enable by default in Solo modes?" description="Whether to automatically enable for every map played in solo mode."]
bool S_EnableDefaultInSolo = false;

[Setting category="LB AntiSnipe" name="Show quick-toggle in main menubar?"]
bool S_ShowQuickToggleMenubar = true;

[Setting category="LB AntiSnipe" name="Show notification when activating/deactivating?"]
bool S_ShowNotifOnToggle = true;
