import ApplicativeRouter
import HttpPipeline
import Models
import Prelude
import Tagged
import UrlFormEncoding

public protocol TaggedType {
  associatedtype Tag
  associatedtype RawValue

  var rawValue: RawValue { get }
  init(rawValue: RawValue)
}

extension Tagged: TaggedType {}

extension PartialIso where B: TaggedType, A == B.RawValue {
  public static var tagged: PartialIso<B.RawValue, B> {
    return PartialIso(
      apply: B.init(rawValue:),
      unapply: ^\.rawValue
    )
  }
}

public func payload<A, B>(
  _ iso1: PartialIso<String, A>,
  _ iso2: PartialIso<String, B>,
  separator: String = "--POINT-FREE-BOUNDARY--"
  )
  -> PartialIso<String, (A, B)> {

    return PartialIso<String, (A, B)>(
      apply: { payload in
        let parts = payload.components(separatedBy: separator)
        guard
          let first = parts.first.flatMap(iso1.apply),
          let second = parts.last.flatMap(iso2.apply) else { return nil }
        return (first, second)
    },
      unapply: { first, second in
        guard
          let first = iso1.unapply(first),
          let second = iso2.unapply(second)
          else { return nil }
        return "\(first)\(separator)\(second)"
    })
}

let isTest: Router<Bool?> =
  formField("live", .string).map(isPresent >>> negate >>> Optional.iso.some)
    <|> formField("test", .string).map(isPresent >>> Optional.iso.some)

let isPresent = PartialIso<String, Bool>(apply: const(true), unapply: { $0 ? "" : nil })
let negate = PartialIso<Bool, Bool>(apply: (!), unapply: (!))

let formDecoder: UrlFormDecoder = {
  let decoder = UrlFormDecoder()
  decoder.parsingStrategy = .bracketsWithIndices
  return decoder
}()

extension PartialIso where A == (String?, Int?), B == Pricing {
  static var pricing: PartialIso {
    return PartialIso(
      apply: { plan, quantity in
        let billing = plan.flatMap(Pricing.Billing.init(rawValue:)) ?? .monthly
        let quantity = clamp(1..<Pricing.validTeamQuantities.upperBound) <| (quantity ?? 1)
        return Pricing(billing: billing, quantity: quantity)
    }, unapply: { pricing -> (String?, Int?) in
      (pricing.billing.rawValue, pricing.quantity)
    })
  }
}

func slug(for string: String) -> String {
  return string
    .lowercased()
    .replacingOccurrences(of: "[\\W]+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "\\A-|-\\z", with: "", options: .regularExpression)
}

extension PartialIso {
  /// Promotes a partial iso to one that deals with tagged values, e.g.
  ///
  ///    PartialIso<String, User.Id>.tagged(.string)
  public static func tagged<T, C>(
    _ iso: PartialIso<A, C>
    ) -> PartialIso<A, B>
    where B == Tagged<T, C> {

      return iso >>> .tagged
  }
}

public func parenthesize<A, B, C, D, E, F>(_ f: PartialIso<(A, B, C, D, E), F>) -> PartialIso<(A, (B, (C, (D, E)))), F> {
  return flatten() >>> f
}

private func flatten<A, B, C, D, E>() -> PartialIso<(A, (B, (C, (D, E)))), (A, B, C, D, E)> {
  return .init(
    apply: { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1.0, $0.1.1.1.1) },
    unapply: { ($0, ($1, ($2, ($3, $4)))) }
  )
}
