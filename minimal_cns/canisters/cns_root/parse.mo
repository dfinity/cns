import Text "mo:base/Text";
import Iter "mo:base/Iter";

module {
  public func getTldFromDomain(domain : Text) : Text {
    let parts = Text.split(domain, #char '.');
    let array = Iter.toArray(parts);
    if (array.size() < 2) return "..";

    let tldText = array[array.size() - 2];
    "." # tldText # ".";
  };
}