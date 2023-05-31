const string LBANTISNIPE_SCRIPT_TXT = """
 #Const C_PageUID "LBAntiSnipe"
 #Include "TextLib" as TL


 #Struct K_TMxSM_Record_Record { Integer Rank; Text AccountId; Text DisplayName; Integer Time; }
 #Struct K_TMxSM_Record_Records { Text ZoneName; Integer WorstTime; Boolean IsFull; Integer Type; K_TMxSM_Record_Record[] Records; }


declare Text G_PreviousMapUid;


// logging function, should be "MLHook_LogMe_" + PageUID
Void MLHookLog(Text msg) {
    SendCustomEvent("MLHook_LogMe_"^C_PageUID, [msg]);
}

declare Boolean MapChanged;
declare Boolean CurrentlyEnabled;

Void CheckMapChange() {
    if (Map != Null && Map.MapInfo.MapUid != G_PreviousMapUid) {
        G_PreviousMapUid = Map.MapInfo.MapUid;
        MapChanged = True;
    } else {
        MapChanged = False;
    }
}

declare Integer Last_RR_ZonesRecordsUpdate;
// first set of records after loading map
declare K_TMxSM_Record_Records[] Cached_RR_ZonesRecords;
// most recent set of records that we overwrite
declare K_TMxSM_Record_Records[] Actual_RR_ZonesRecords;


K_TMxSM_Record_Records PatchRecsWith(K_TMxSM_Record_Records[] records, Text Zone, K_TMxSM_Record_Record Record) {
    foreach (recs in records) {
        if (recs.ZoneName != Zone) continue;
        declare K_TMxSM_Record_Record[] NewRecords = [];
        declare Boolean HasAdded = False;
        foreach (rec in recs.Records) {
            if (rec.AccountId == Record.AccountId) {
                // ignore users previous records
                MLHookLog("Ignoring previous time: " ^ rec);
                continue;
            } else if (Record.Time < rec.Time && !HasAdded) {
                HasAdded = True;
                declare RecCopy = Record;
                if (NewRecords.count < 5) {
                    RecCopy.Rank = NewRecords.count + 1;
                }
                NewRecords.add(RecCopy);
            } else {
                // don't add records past 5 to avoid leaderboard mixups; could also use the surround times from new records to add more if we want
                if (NewRecords.count < 5) {
                    declare newRec = rec;
                    newRec.Rank = NewRecords.count + 1;
                    NewRecords.add(newRec);
                }
            }
        }
        if (!HasAdded) {
            NewRecords.add(Record);
        }
        declare newRecs = recs;
        newRecs.Records = NewRecords;
        return newRecs;
    }

    declare NewRecord = Record;
    NewRecord.Rank = 1;
    return K_TMxSM_Record_Records {
        ZoneName = Zone,
        Records = [NewRecord],
        WorstTime = -1,
        IsFull = False,
        Type = 1
    };
}


K_TMxSM_Record_Records GetRecsForZone(K_TMxSM_Record_Records[] records, Text Zone) {
    foreach (recs in records) {
        if (recs.ZoneName == Zone) {
            return recs;
        }
    }
    return K_TMxSM_Record_Records {
        ZoneName = Zone,
        Records = [],
        WorstTime = -1,
        IsFull = False,
        Type = 1
    };
}

K_TMxSM_Record_Records[] PatchWorldRecords(K_TMxSM_Record_Records[] newRecords) {
    declare K_TMxSM_Record_Records[] ret = [];

    foreach (records in newRecords) {
        MLHookLog(records.ZoneName);
        if (records.ZoneName == "World") {
            // compare to cached records
            declare Boolean foundPlayer = False;
            for (I, 0, records.Records.count - 1) {
                declare newTime = records.Records[I];
                if (newTime.AccountId == LocalUser.WebServicesUserId) {
                    MLHookLog("New player time: " ^ newTime);
                    MLHookLog("Previous records: " ^ records);
                    declare patched = PatchRecsWith(Cached_RR_ZonesRecords, "World", newTime);
                    MLHookLog("Patched records: " ^ patched);
                    ret.add(patched);
                    foundPlayer = True;
                    break;
                }
            }
            if (!foundPlayer) {
                ret.add(records);
            }
        } else {
            ret.add(records);
        }
    }

    return ret;
}



Void CheckNewRecordsAndPatch() {
    if (!CurrentlyEnabled) return;
    declare Integer Race_Record_ZonesRecordsUpdate for ClientUI;

    if (Race_Record_ZonesRecordsUpdate != Last_RR_ZonesRecordsUpdate) {
        declare K_TMxSM_Record_Records[] Race_Record_ZonesRecords for ClientUI;

        // new records have been delivered -- time to patch them
        Actual_RR_ZonesRecords = Race_Record_ZonesRecords;

        // if we don't have cached records, cache the current ones
        if (Cached_RR_ZonesRecords.count == 0) {
            Cached_RR_ZonesRecords = Race_Record_ZonesRecords;
        }
        Race_Record_ZonesRecords = PatchWorldRecords(Race_Record_ZonesRecords);
        // ensure we trigger an update after writing new records
        Race_Record_ZonesRecordsUpdate = Race_Record_ZonesRecordsUpdate + 1;

        Last_RR_ZonesRecordsUpdate = Race_Record_ZonesRecordsUpdate;
    }
}


Void OnDisableMsg() {
    if (!CurrentlyEnabled) return;
    MLHookLog("Disabling.");
    if (Actual_RR_ZonesRecords.count > 0) {
        declare K_TMxSM_Record_Records[] Race_Record_ZonesRecords for ClientUI;
        declare Integer Race_Record_ZonesRecordsUpdate for ClientUI;
        Race_Record_ZonesRecords = Actual_RR_ZonesRecords;
        Race_Record_ZonesRecordsUpdate = Race_Record_ZonesRecordsUpdate + 1;
    }
    CurrentlyEnabled = False;
}

Void OnEnableMsg() {
    if (CurrentlyEnabled) return;
    MLHookLog("Enabling.");
    Last_RR_ZonesRecordsUpdate = -1;
    Cached_RR_ZonesRecords = [];
    Actual_RR_ZonesRecords = [];
    CurrentlyEnabled = True;
    CheckNewRecordsAndPatch();
}


// from angelscript

Void CheckIncoming() {
    declare Text[][] MLHook_Inbound_LBAntiSnipe for ClientUI;
    foreach (Event in MLHook_Inbound_LBAntiSnipe) {
        if (Event.count < 2) {
            if (Event[0] == "Disable") {
                OnDisableMsg();
            } else if (Event[0] == "Enable") {
                OnEnableMsg();
            } else {
                MLHookLog("Skipped unknown incoming event: " ^ Event);
                continue;
            }
        } else {
            MLHookLog("Skipped unknown incoming event: " ^ Event);
            continue;
        }
    }
    MLHook_Inbound_LBAntiSnipe = [];
}


Void OnFirstLoad() {
    MapChanged = False;
    CurrentlyEnabled = False;

	declare K_TMxSM_Record_Records[] Race_Record_ZonesRecords for ClientUI;
	declare Integer Race_Record_ZonesRecordsUpdate for ClientUI;
    MLHookLog(""^Race_Record_ZonesRecords);
}

Void OnMapChange() {
    CurrentlyEnabled = False;
    Cached_RR_ZonesRecords = [];
}


main() {
    declare Integer LoopCounter = 0;
    MLHookLog("\\$888Starting LBAntiSnipe ML");
    yield;
    OnFirstLoad();
    while (True) {
        yield;
        LoopCounter += 1;
        CheckIncoming();
        CheckMapChange();
        if (MapChanged) OnMapChange();

        // main logic
        CheckNewRecordsAndPatch();
    }
}
""";