// Posts the notification the Music app sends when a song starts playing, so the Apple Music
// widget can be checked (and screenshotted) without playing anything.
import Foundation

DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.apple.Music.playerInfo"),
    object: "com.apple.Music.player",
    userInfo: ["Player State": "Playing", "Name": "Clair de Lune", "Artist": "Claude Debussy", "Album": "Suite bergamasque"],
    deliverImmediately: true)
