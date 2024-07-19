#ifndef PACKY_STRUCTS_HPP
#define PACKY_STRUCTS_HPP

#include "clipper2/clipper.h"

namespace Packy {

  // ItemDef and Item

  struct ItemDef {

    ItemDef(int id, int count, int rotations, Clipper2Lib::PathsD paths);
    ~ItemDef();

    int id;
    int count;
    int rotations;

    Clipper2Lib::PathsD paths;

    int16_t item_type_id;

  };

  struct Item {

    explicit Item(ItemDef* def);
    ~Item();

    ItemDef* def;

    double x;
    double y;
    double angle;

  };

  using ItemDefs = std::vector<ItemDef>;
  using Items = std::vector<Item>;

  // Cut

  struct Cut {

    explicit Cut(int16_t depth, int64_t x1, int64_t y1, int64_t x2, int64_t y2);
    ~Cut();

    int16_t depth;

    int64_t x1;
    int64_t y1;
    int64_t x2;
    int64_t y2;

  };

  using Cuts = std::vector<Cut>;

  // BinDef and Bin

  struct BinDef {

    BinDef(int id, int count, double length, double width, int type);
    ~BinDef();

    int id;
    int count;

    double length;
    double width;

    int type;

    int16_t bin_type_id;

  };

  struct Bin {

    explicit Bin(BinDef* def);
    ~Bin();

    BinDef* def;

    Items items;
    Cuts cuts;

  };

  using BinDefs = std::vector<BinDef>;
  using Bins = std::vector<Bin>;

  // Solution

  struct Solution {

    Solution();
    ~Solution();

    Bins unused_bins;
    Bins packed_bins;

    Items unplaced_items;

    void clear();
    std::string format();

  };

  // -- Converters

  size_t GetCItemArrayLen();
  size_t GetCItemsArrayLen(const Items& items);
  size_t GetCBinArrayLen(const Bin& bin);
  size_t GetCBinsArrayLen(const Bins& bins);

  void ConvertItemToCItem(const Item& item, double*& v);
  void ConvertItemsToCItems(const Items& items, double*& v);
  void ConvertCutToCCut(const Cut& cut, double*& v);
  void ConvertCutsToCCuts(const Cuts& cuts, double*& v);
  void ConvertBinToCBin(const Bin& bin, double*& v);
  void ConvertBinsToCBins(const Bins& bins, double*& v);
  double* ConvertSolutionToCSolution(const Solution& solution);

}

#endif // PACKY_STRUCTS_HPP
