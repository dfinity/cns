import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Metrics "backend/metrics";

module {
  public func isEqualInt(actual : Int, expected : Int, errMsg : Text) : Bool {
    let isEq = actual == expected;
    if (not isEq) {
      Debug.print("Expected Int: " # debug_show (expected) # ", got: " # debug_show (actual) # "; error: " # errMsg);
    };
    return isEq;
  };

  public func isEqualText(actual : Text, expected : Text, errMsg : Text) : Bool {
    let isEq = actual == expected;
    if (not isEq) {
      Debug.print("Expected Text: '" # debug_show (expected) # "', got: '" # debug_show (actual) # "'; error: " # errMsg);
    };
    return isEq;
  };

  public func isEqualMetrics(actual : Metrics.MetricsData, expected : Metrics.MetricsData) : Bool {
    var isEq = actual == expected;
    if (not isEq) {
      Debug.print("Expected Metrics: '" # debug_show (expected) # "', got: '" # debug_show (actual) );
    };
    return isEq;
  };

  public func textContains(text : Text, subText : Text, errMsg : Text) : Bool {
    let contains = Text.contains(text, #text subText);
    if (not contains) {
      Debug.print("Expected text '" # text # "' to contain '" # subText # "', error: " # errMsg);
    };
    return contains;
  };

  public func isTrue(actual : Bool, errMsg : Text) : Bool {
    if (not actual) {
      Debug.print("Expected Bool to be true, error: " # errMsg);
    };
    return actual;
  };
};
