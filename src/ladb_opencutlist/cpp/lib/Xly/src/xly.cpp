#include "xly.hpp"

#include <iostream>

#include "xlsxwriter.h"

#include <sstream>
#include <nlohmann/json.hpp>

using namespace nlohmann;

#ifdef __cplusplus
extern "C" {
#endif

static std::string str_output_;

DLL_EXPORTS char* c_write_to_xlsx(
        const char* s_input
) {

    try {

        std::stringstream ss(s_input);

        json j;
        ss >> j;

        /*
         * {
         *  "filename": "file.xlsx",
         *  "worksheets": [
         *      {
         *          "name": "sheet1",
         *          "cells": [
         *              {
         *                  "row": 0,
         *                  "col": 0,
         *                  "value": "Hello"
         *              },
         *              {
         *                  "row": 1,
         *                  "col": 0,
         *                  "value": 123
         *              },
         *              {
         *                  "row": 1,
         *                  "col": 0,
         *                  "formula": "=SUM(1, 2, 3)"
         *              },
         *          ]
         *      }
         *  ]
         * }
         *
         *
         */

        std::string filename = j.value("filename", "file.xlsx");

        lxw_workbook  *workbook  = workbook_new(filename.c_str());

        if (j.contains("worksheets")) {

            auto& j_worksheets = j["worksheets"];
            for (auto& j_worksheet_item: j_worksheets.items()) {
                auto& j_worksheet = j_worksheet_item.value();

                std::string name = j_worksheet.value("name", "sheet1");

                lxw_worksheet *worksheet = workbook_add_worksheet(workbook, name.c_str());

                if (j_worksheet.contains("cells")) {

                    auto& j_cells = j_worksheet["cells"];
                    for (auto& j_cell_item: j_cells.items()) {
                        auto& j_cell = j_cell_item.value();

                        lxw_row_t row = j_cell.value("row", 0);
                        lxw_row_t col = j_cell.value("col", 0);

                        if (j_cell.contains("value")) {
                            auto value_type_name = j_cell["value"].type_name();
                            if (std::strcmp(value_type_name, "number") == 0) {
                                worksheet_write_number(worksheet, row, col, j_cell.value("value", 0.0), NULL);
                            } else if (std::strcmp(value_type_name, "string") == 0) {
                                worksheet_write_string(worksheet, row, col, j_cell.value("value", "").c_str(), NULL);
                            }
                        } else if (j_cell.contains("formula")) {
                            worksheet_write_formula(worksheet, row, col, j_cell.value("formula", "").c_str(), NULL);
                        }

                    }

                }

            }

        }

        workbook_close(workbook);

        str_output_ = json{
            {"success", true}
        }.dump();

    } catch (const std::exception& e) {
        str_output_ = json{
            {"error", e.what()}
        }.dump();
    }
    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_version() {
    return const_cast<char*>(XLY_VERSION);
}

#ifdef __cplusplus
}
#endif