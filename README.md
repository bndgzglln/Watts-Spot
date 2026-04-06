# SpotPrice

SwiftUI iPhone app for Austria spot electricity prices using the Energy Charts API:

`https://api.energy-charts.info/price?bzn=AT`

## Features

- Current quarter-hour price card
- Day-ahead summary card for tomorrow's published values
- Red-to-green bar chart from high to low price intensity
- Detailed interval list with the live slot highlighted
- Pull-to-refresh loading
- Local notifications for next-day publication and the cheapest tomorrow slot
- Home Screen widget with a current-price min-max gauge

## Open the app

1. Open `SpotPrice.xcodeproj` in Xcode.
2. Set your own bundle identifier and signing team.
3. Run on an iPhone simulator or device.

## Notes

- Prices from the API are delivered in `EUR/MWh`; the UI also converts them to `ct/kWh`.
- Time grouping uses the `Europe/Vienna` timezone so "today" and "day-ahead" align with Austria.
