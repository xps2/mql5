//+------------------------------------------------------------------+
//|                                    BullishBearlishStatistics.mq5 |
//|                                            Copyright 2020, bonta |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, bonta"
#property version   "1.00"
#property script_show_inputs

#include <Generic\HashMap.mqh>
#include <Arrays\ArrayString.mqh>

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
    const ENUM_TIMEFRAMES convert_tf = (InputSymbolPeriod == PERIOD_CURRENT) ?  ChartPeriod(0) : InputSymbolPeriod;

    if (CopyOpen(InputSymbolName, convert_tf, InputDateStart, date_finish, open_array) == -1) {
        return;
    }
    if (CopyClose(InputSymbolName, convert_tf, InputDateStart, date_finish, close_array) == -1) {
        return;
    }
    if (CopyTime(InputSymbolName, convert_tf, InputDateStart, date_finish, date_array) == -1) {
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

    // 計算し終えたので解放
    ArrayFree(open_array);
    ArrayFree(close_array);

    // 集計
    CHashMap<string, int> sum_dict, sum_bull_dict, sum_bear_dict, sum_same_dict;
    for (int i = 0; i < size; i++) {
        string timeS = FormatTortalizationTime(convert_tf, date_array[i]);
        if (timeS == NULL) {
            break;
        }

        int temp_sum = 0;
        if (sum_dict.TryGetValue(timeS, temp_sum)) {
            sum_dict.TrySetValue(timeS, temp_sum + 1);
        } else {
            sum_dict.Add(timeS, 1);
        }

        if (flag_array[i] == InputBullish) {
            int temp_bull = 0;
            if (sum_bull_dict.TryGetValue(timeS, temp_bull)) {
                sum_bull_dict.TrySetValue(timeS, temp_bull + 1);
            } else {
                sum_bull_dict.Add(timeS, 1);
            }
        } else if (flag_array[i] == InputBearlish) {
            int temp_bear = 0;
            if (sum_bear_dict.TryGetValue(timeS, temp_bear)) {
                sum_bear_dict.TrySetValue(timeS, temp_bear + 1);
            } else {
                sum_bear_dict.Add(timeS, 1);
            }
        } else {
            int temp_same = 0;
            if (sum_same_dict.TryGetValue(timeS, temp_same)) {
                sum_same_dict.TrySetValue(timeS, temp_same + 1);
            } else {
                sum_same_dict.Add(timeS, 1);
            }
        }
    }

    CHashMap<string, double> percentage_bull, percentage_bear, percentage_same;
    string key_array_temp[];
    CArrayString *key_array = new CArrayString;
    int value_array[];

    // キーをソートするために変換、値は不要
    sum_dict.CopyTo(key_array_temp, value_array, 0);
    ArrayFree(value_array);

    key_array.AddArray(key_array_temp);
    key_array.Sort(0);
    
    // 確率計算
    for (int i = 0; i < key_array.Total(); i++) {
        string timeS = key_array[i];
        int sum;
        sum_dict.TryGetValue(timeS, sum);

        int temp_bull = 0;
        if (sum_bull_dict.TryGetValue(timeS, temp_bull)) {
            percentage_bull.Add(timeS, temp_bull / (double)sum);
        } else {
            percentage_bull.Add(timeS, 0);
        }
        
        int temp_bear = 0;
        if (sum_bear_dict.TryGetValue(timeS, temp_bear)) {
            percentage_bear.Add(timeS, temp_bear / (double)sum);
        } else {
            percentage_bear.Add(timeS, 0);
        }
        
        int temp_same = 0;
        if (sum_same_dict.TryGetValue(timeS, temp_same)) {
            percentage_same.TrySetValue(timeS, temp_same / (double)sum);
        } else {
            percentage_same.Add(timeS, 0);
        }

    }

    const string file_name_base = InputSymbolName + "-" + EnumToString(convert_tf) + "-" + FormatTime(date_array[0]) + "-" + FormatTime(date_finish);
    const string output_file_name = file_name_base + ".csv";
    MakeBullishBearlishFile(output_file_name, date_array, flag_array);

    const string statistics_file_name = file_name_base + "-stat.csv";
    MakeStatisticsFile(statistics_file_name, convert_tf,
                       sum_dict, sum_bull_dict, sum_bear_dict, sum_same_dict,
                       percentage_bull, percentage_bear, percentage_same,
                       key_array);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MakeBullishBearlishFile(const string file_name,
                             datetime &date_array[],
                             string &flag_array[]) {
    int file_handle = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_CSV | FILE_UNICODE);
    if (file_handle != INVALID_HANDLE) {
        Alert(file_name, " file is available for writing");
        Alert("File path: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\Files\\");
        for(int i = 0; i < ArraySize(date_array); i++) {
            FileWrite(file_handle, date_array[i], flag_array[i]);
        }
        FileClose(file_handle);
        Alert("Data is written, ", file_name, " file is closed");
        Alert("完了!");
    } else {
        Alert("Failed to open ", file_name, " file, Error code = ", GetLastError());
    }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MakeStatisticsFile(const string file_name,
                        const ENUM_TIMEFRAMES &tf,
                        CHashMap<string, int> &sum_dict,
                        CHashMap<string, int> &sum_bull_dict,
                        CHashMap<string, int> &sum_bear_dict,
                        CHashMap<string, int> &sum_same_dict,
                        CHashMap<string, double> &percentage_bull,
                        CHashMap<string, double> &percentage_bear,
                        CHashMap<string, double> &percentage_same,
                        CArrayString &key_array) {

    int file_handle = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_CSV | FILE_UNICODE);
    if (file_handle != INVALID_HANDLE) {
        Alert(file_name, " file is available for writing");
        Alert("File path: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\Files\\");

        FileWrite(file_handle, "", "総データ数", "陽線合計", "陰線合計", "同値合計", "陽線確率(陽線合計/総データ数)", "陰線確率(陰線合計/総データ数)", "同値確率(同値合計/総データ数)");
        for(int i = 0; i < key_array.Total(); i++) {
            int temp_sum, temp_sum_bull, temp_sum_bear, temp_sum_same;
            double temp_bull, temp_bear, temp_same;
            sum_dict.TryGetValue(key_array[i], temp_sum);
            sum_bull_dict.TryGetValue(key_array[i], temp_sum_bull);
            sum_bear_dict.TryGetValue(key_array[i], temp_sum_bear);
            sum_same_dict.TryGetValue(key_array[i], temp_sum_same);
            percentage_bull.TryGetValue(key_array[i], temp_bull);
            percentage_bear.TryGetValue(key_array[i], temp_bear);
            percentage_same.TryGetValue(key_array[i], temp_same);

            FileWrite(file_handle, key_array[i], temp_sum, temp_sum_bull, temp_sum_bear, temp_sum_same, temp_bull, temp_bear, temp_same);
        }
        FileClose(file_handle);
        Alert("Data is written, ", file_name, " file is closed");
        Alert("完了!");
    } else {
        Alert("Failed to open ", file_name, " file, Error code = ", GetLastError());
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
//|                                                                  |
//+------------------------------------------------------------------+
string FormatTortalizationTime(const ENUM_TIMEFRAMES &tf, const datetime time) {
    MqlDateTime mdt;
    TimeToStruct(time, mdt);


    if (tf >= PERIOD_MN1) {
        return StringFormat("%02d", mdt.mon);
    }

    if (tf >= PERIOD_W1) {
        return StringFormat("%02d_%d", mdt.mon, (int)MathCeil(mdt.day / 7.0));
    }

    if (tf >= PERIOD_D1) {
        return StringFormat("%02d/%02d", mdt.mon, mdt.day);
    }

    if (tf >= PERIOD_H1) {
        return StringFormat("%02d:%02d:%02d", mdt.hour, mdt.min, mdt.sec);
    }

    if (tf >= PERIOD_M1) {
        return StringFormat("%02d:%02d", mdt.min, mdt.sec);
    }

    return NULL;
}


//+------------------------------------------------------------------+
