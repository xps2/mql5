//+------------------------------------------------------------------+
//|                                    BullishBearlishStatistics.mq5 |
//|                                            Copyright 2020, bonta |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, bonta"
#property version   "1.00"
#property script_show_inputs

input group "入力パラメータ"
input string InputSymbolName = "USDJPY";         // 銘柄
input ENUM_TIMEFRAMES InputSymbolPeriod = PERIOD_D1;     // 時間軸
input datetime InputDateStart = D'2001.01.01 00:00'; // 開始日時
input datetime InputDateFinish = -1; // 終了日時(空の場合、現在日時)

input group "CSVに書き込む値"
input string InputBullish = "1"; // 陽線
input string InputBearlish = "-1"; // 陰線
input string InputSame = "0"; // 同値

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {

    double open_array[], close_array[];
    string flag_array[];
    datetime date_array[];
    const datetime date_finish = InputDateFinish == -1 ? TimeCurrent() : InputDateFinish;

    if (CopyOpen(InputSymbolName, InputSymbolPeriod, InputDateStart, date_finish, open_array) == -1) {
        return;
    }
    if (CopyClose(InputSymbolName, InputSymbolPeriod, InputDateStart, date_finish, close_array) == -1) {
        return;
    }
    if (CopyTime(InputSymbolName, InputSymbolPeriod, InputDateStart, date_finish, date_array) == -1) {
        return;
    }

    if (ArraySize(open_array) != ArraySize(close_array)
            || ArraySize(open_array) != ArraySize(date_array)
            || ArraySize(close_array) != ArraySize(date_array)) {
        return;
    }
    const int size = ArraySize(open_array);

    ArrayResize(flag_array, size);

    for (int i = 0; i < size; i++) {
        if (open_array[i] > close_array[i]) {
            flag_array[i] = InputBearlish;
        } else if (open_array[i] < close_array[i]) {
            flag_array[i] = InputBullish;
        } else {
            flag_array[i] = InputSame;
        }
    }

    const string input_file_name = InputSymbolName + "-" + EnumToString(InputSymbolPeriod) + "-" + FormatTime(InputDateStart) + "-" + FormatTime(date_finish) + ".csv";
    int file_handle = FileOpen(input_file_name, FILE_READ | FILE_WRITE | FILE_CSV | FILE_UNICODE);
    if(file_handle != INVALID_HANDLE) {
        Alert(input_file_name, " file is available for writing");
        Alert("File path: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\Files\\");
        for(int i = 0; i < size; i++) {
            FileWrite(file_handle, date_array[i], flag_array[i]);
        }
        //--- ファイルを閉じる
        FileClose(file_handle);
        Alert("Data is written, ", input_file_name, " file is closed");
        Alert("完了!");
    } else {
        Alert("Failed to open ", input_file_name, " file, Error code = ", GetLastError());
    }

}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string FormatTime(const datetime time) {
    MqlDateTime mdt;

    TimeToStruct(time, mdt);

    return StringFormat("%04d%02d%02d_%02d%02d%02d", mdt.year, mdt.mon, mdt.day, mdt.hour, mdt.min, mdt.sec);

}

//+------------------------------------------------------------------+
