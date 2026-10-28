// Posts the notification Spotify sends when a song starts playing. CI has no Spotify, so
// this is how the screenshots show the Spotify widget with a track.
import Foundation

DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.spotify.client.PlaybackStateChanged"),
    object: "com.spotify.client",
    userInfo: ["Player State": "Playing", "Name": "Midnight City", "Artist": "M83"],
    deliverImmediately: true)
