import Foundation
import Html
import HttpPipeline
import Models
import PointFreeRouter
import Prelude
import Syndication

let episodesRssMiddleware: Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data> =
  writeStatus(.ok)
    >=> respond(episodesFeedView, contentType: .text(.init(rawValue: "xml"), charset: .utf8))
    >=> clearHeadBody

private let episodesFeedView = itunesRssFeedLayout { (_: Prelude.Unit) in
  [
    node(
      rssChannel: freeEpisodeRssChannel,
      items: items()
    )
  ]
}

var freeEpisodeRssChannel: RssChannel {
  let description = """
Point-Free is a video series about functional programming and the Swift programming language. Each episode \
covers a topic that may seem complex and academic at first, but turns out to be quite simple. At the end of \
each episode we’ll ask “what’s the point?!”, so that we can bring the concepts back down to earth and show \
how these ideas can improve the quality of your code today.
"""
  let title = "Point-Free Videos"

  return RssChannel(
    copyright: "Copyright Point-Free, Inc. \(Calendar.current.component(.year, from: Current.date()))",
    description: description,
    image: .init(
      link: url(to: .home),
      title: title,
      url: "https://d3rccdn33rt8ze.cloudfront.net/social-assets/pf-avatar-square.jpg"
    ),
    itunes: .init(
      author: "Brandon Williams & Stephen Celis",
      categories: [
        .init(name: "Technology", subcategory: "Software How-To"),
        .init(name: "Education", subcategory: "Training"),
        ],
      explicit: false,
      keywords: [
        "programming",
        "development",
        "mobile",
        "ios",
        "functional",
        "swift",
        "apple",
        "developer",
        "software engineering",
        "server",
        "app"
      ],
      image: .init(href: "https://d3rccdn33rt8ze.cloudfront.net/social-assets/pf-avatar-square.jpg"),
      owner: .init(email: "support@pointfree.co", name: "Brandon Williams & Stephen Celis"),
      subtitle: "Functional programming concepts explained simply.",
      summary: description,
      type: .episodic
    ),
    language: "en-US",
    link: url(to: .home),
    title: title
  )
}

private func items() -> [RssItem] {
  return Current
    .episodes()
    .sorted(by: their({ $0.freeSince ?? $0.publishedAt }, >))
    .map { item(episode: $0) }
}

private func item(episode: Episode) -> RssItem {

  func title(episode: Episode) -> String {
    return episode.subscriberOnly
      ? episode.title
      : "🆓 \(episode.title)"
  }

  func summary(episode: Episode) -> String {
    return episode.subscriberOnly
      ? "🔒 \(episode.blurb)"
      : "🆓 \(episode.blurb)"
  }

  func description(episode: Episode) -> String {
    switch episode.permission {
    case .free:
      return """
Every once in awhile we release a new episode free for all to see, and today is that day! Please enjoy \
this episode, and if you find this interesting you may want to consider a subscription \
\(url(to: .pricingLanding)).

---

\(episode.blurb)
"""
    case let .freeDuring(range) where range.contains(Current.date()):
      return """
Free Episode: Every once in awhile we release a past episode for free to all of our viewers, and today is \
that day! Please enjoy this episode, and if you find this interesting you may want to consider a \
subscription \(url(to: .pricingLanding)).

---

\(episode.blurb)
"""
    case .freeDuring, .subscriberOnly:
      return """
Subscriber-Only: Today's episode is available only to subscribers. If you are a Point-Free subscriber you \
can access your private podcast feed by visiting \(url(to: .account(.index))).

---

\(episode.blurb)
"""
    }
  }

  func enclosure(episode: Episode) -> RssItem.Enclosure {
    return episode.subscriberOnly
      ? .init(
        length: episode.trailerVideo?.bytesLength ?? 0,
        type: "video/mp4",
        url: episode.trailerVideo?.downloadUrl ?? ""
        )
      : .init(
        length: episode.fullVideo.bytesLength,
        type: "video/mp4",
        url: episode.fullVideo.downloadUrl
    )
  }

  func mediaContent(episode: Episode) -> RssItem.Media.Content {
    return episode.subscriberOnly
      ? .init(
        length: episode.trailerVideo?.bytesLength ?? 0,
        medium: "video",
        type: "video/mp4",
        url: episode.trailerVideo?.downloadUrl ?? ""
        )
      : .init(
        length: episode.fullVideo.bytesLength,
        medium: "video",
        type: "video/mp4",
        url: episode.fullVideo.downloadUrl
    )
  }

  return RssItem(
    description: description(episode: episode),
    dublinCore: .init(creators: ["Brandon Williams", "Stephen Celis"]),
    enclosure: enclosure(episode: episode),
    guid: String(Int((episode.freeSince ?? episode.publishedAt).timeIntervalSince1970)),
    itunes: RssItem.Itunes(
      author: "Brandon Williams & Stephen Celis",
      duration: episode.length,
      episode: episode.sequence,
      episodeType: episode.subscriberOnly ? .trailer : .full,
      explicit: false,
      image: episode.itunesImage ?? "",
      subtitle: summary(episode: episode),
      summary: summary(episode: episode),
      season: 1,
      title: title(episode: episode)
    ),
    link: url(to: .episode(.show(.left(episode.slug)))),
    media: .init(
      content: mediaContent(episode: episode),
      title: title(episode: episode)
    ),
    pubDate: episode.freeSince ?? episode.publishedAt,
    title: title(episode: episode)
  )
}

// TODO: swift-web
extension Html.Application {
  public static var atom = Html.Application(rawValue: "atom+xml")
}

public func respond<A>(_ view: @escaping (A) -> Node, contentType: MediaType = .html) -> Middleware<HeadersOpen, ResponseEnded, A, Data> {
  return { conn in
    conn
      |> respond(
        body: Current.renderXml(view(conn.data)),
        contentType: contentType
    )
  }
}

public func respond<A>(_ node: Node, contentType: MediaType = .html) -> Middleware<HeadersOpen, ResponseEnded, A, Data> {
  return { conn in
    conn
      |> respond(
        body: Current.renderXml(node),
        contentType: contentType
    )
  }
}
