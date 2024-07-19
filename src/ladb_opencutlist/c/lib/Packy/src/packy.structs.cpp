#include "packy.hpp"
#include "packy.structs.hpp"

#include <utility>

namespace Packy {

  // ItemDef and Item

  ItemDef::ItemDef(int id, int count, int rotations, Clipper2Lib::PathsD paths) :
    id(id),
    count(count),
    rotations(rotations),
    paths(std::move(paths)),
    item_type_id(0) {}

  ItemDef::~ItemDef() = default;


  Item::Item(ItemDef* def) :
    def(def),
    x(0),
    y(0),
    angle(0) {}

  Item::~Item() = default;


  // Cut

  Cut::Cut(int16_t depth, int64_t x1, int64_t y1, int64_t x2, int64_t y2) :
    depth(depth),
    x1(x1),
    y1(y1),
    x2(x2),
    y2(y2) {}

  Cut::~Cut() = default;


  // BinDef and Bin

  BinDef::BinDef(int id, int count, double length, double width, int type) :
    id(id),
    count(count),
    length(length),
    width(width),
    type(type),
    bin_type_id(0) {}

  BinDef::~BinDef() = default;


  Bin::Bin(BinDef* def) :
    def(def) {}

  Bin::~Bin() = default;


  // Solution

  Solution::Solution() = default;
  Solution::~Solution() = default;

  void Solution::clear() {
    this->unused_bins.clear();
    this->packed_bins.clear();
    this->unplaced_items.clear();
  }

  std::string Solution::format() {
    return "solution.unused_bins.size = " + std::to_string(this->unused_bins.size()) + "\n"
           "solution.packed_bins.size = " + std::to_string(this->packed_bins.size()) + "\n"
           "solution.unplaced_items.size = " + std::to_string(this->unplaced_items.size()) + "\n";
  }

  // -- Converters

  size_t GetCItemArrayLen() {
    return 4 /* id, x, y, angle */;
  }

  size_t GetCItemsArrayLen(const Items &items) {
    return 1 /* Number of items */ + items.size() * GetCItemArrayLen();
  }

  size_t GetCCutArrayLen() {
    return 5 /* depth, x1, y1, x2, y2 */;
  }

  size_t GetCCutsArrayLen(const Cuts &cuts) {
    return 1 /* Number of cuts */ + cuts.size() * GetCCutArrayLen();
  }

  size_t GetCBinArrayLen(const Bin &bin) {
    return 1 /* id */ + GetCItemsArrayLen(bin.items) + GetCCutsArrayLen(bin.cuts);
  }

  size_t GetCBinsArrayLen(const Bins &bins) {
    size_t array_len = 1 /* Number of bins */;
    for (auto &bin : bins) {
      array_len += GetCBinArrayLen(bin);
    }
    return array_len;
  }

  void ConvertItemToCItem(const Item& item, double*& v) {

    /*

     CItem
      |attr  |attr  |attr  |attr
      |id    |x     |y     |angle

     */

    *v++ = static_cast<double>(item.def->id);
    *v++ = static_cast<double>(item.x);
    *v++ = static_cast<double>(item.y);
    *v++ = static_cast<double>(item.angle);

  }

  void ConvertItemsToCItems(const Items& items, double*& v) {

    /*

     CItems
      |counter|item1|item2|...|itemN
      |N      |      |      |...|

      N = Number of items

     */

    *v++ = static_cast<double>(items.size());
    for (auto &item : items) {
      ConvertItemToCItem(item, v);
    }

  }

  void ConvertCutToCCut(const Cut& cut, double *&v) {

    /*

     CCut
      |attr  |attr  |attr  |attr  |attr
      |depth |x1    |y1    |x2    |y2

     */

    *v++ = static_cast<double>(cut.depth);
    *v++ = static_cast<double>(cut.x1);
    *v++ = static_cast<double>(cut.y1);
    *v++ = static_cast<double>(cut.x2);
    *v++ = static_cast<double>(cut.y2);

  }

  void ConvertCutsToCCuts(const Cuts& cuts, double*& v) {

    /*

     CCuts
      |counter|cut1  |cut2  |...|cutN
      |N      |      |      |...|

      N = Number of cuts

     */

    *v++ = static_cast<int64_t>(cuts.size());
    for (auto &cut : cuts) {
      ConvertCutToCCut(cut, v);
    }

  }

  void ConvertBinToCBin(const Bin& bin, double*& v) {

    /*

     CBin
      |attr   |items |cuts
      |id     |       |

     */

    *v++ = static_cast<double>(bin.def->id);
    ConvertItemsToCItems(bin.items, v);
    ConvertCutsToCCuts(bin.cuts, v);

  }

  void ConvertBinsToCBins(const Bins& bins, double*& v) {

    /*

     CBins
      |attr   |bin1|bin2|...|binN
      |N      |    |    |...|

      N = Number of bins

     */

    *v++ = static_cast<double>(bins.size());
    for (auto &bin : bins) {
      ConvertBinToCBin(bin, v);
    }

  }

  double* ConvertSolutionToCSolution(const Solution& solution) {

    /*

     CSolution
      |counter|unused_bins|packed_bins|unplaced_items
      |L      |           |           |

      L = Array length

     */

    size_t array_len = 1 /* Array length */ + GetCBinsArrayLen(solution.unused_bins) + GetCBinsArrayLen(solution.packed_bins) + GetCItemsArrayLen(solution.unplaced_items);
    double* result = new double[array_len], *v = result;
    *v++ = static_cast<double>(array_len);
    ConvertBinsToCBins(solution.unused_bins, v);
    ConvertBinsToCBins(solution.packed_bins, v);
    ConvertItemsToCItems(solution.unplaced_items, v);

    return result;
  }

}