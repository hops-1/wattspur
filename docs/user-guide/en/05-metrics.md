# Metrics: where every value comes from

Wattspur shows two kinds of values:
- **From Bosch:** the totals your drive unit stored in the FIT file (the *session*). Wattspur shows them unchanged, so they match the Flow app.
- **Calculated by Wattspur:** values the file does not contain. Estimates are marked with ⓘ.

## Values from the Bosch file
| Value | Meaning |
|---|---|
| Ride time | Time in motion (timer time), without pauses |
| Total time | From start to finish, including pauses |
| Distance | Total distance |
| Avg speed, Max speed | Average speed while moving; top speed |
| Avg power, Max power | Your own pedalling power in watts, without the motor. Bosch averages only over the seconds in which you pedal; coasting does not lower the average |
| Avg cadence, Max cadence | Pedal revolutions per minute |
| Ascent, Descent | Metres climbed and descended |

## Values calculated by Wattspur
| Value | How |
|---|---|
| Paused | Total time − ride time |
| Work | Your pedalling power added up over the ride: Σ power × 1 s, in kilojoules. If the file contains a total work value, that one is used. Because coasting counts as 0 W here but not in Bosch's average, work is usually lower than avg power × ride time; on a ride with a lot of coasting, much lower |
| Elevation min–max | Lowest and highest altitude in the recording |
| Calories ⓘ | As in the Flow app: work (kJ) × 0.97 plus 64 kcal per hour of ride time. The human body turns roughly a quarter of the energy it uses into pedalling work; the time share stands for everything else it burns meanwhile. The Flow app has no body data, so the share is a fixed value there. Six rides with the Flow value are matched within a few kcal. A mode “With profile” using your body data is prepared for a later version |
| CO₂ saved ⓘ | Distance (km) × 0.159 kg: what an average car would have emitted on the same distance |

The calories and CO₂ factors are assumptions checked against a few rides. They may change in later versions; the changelog will say so.

## Values from a GPX file
A GPX file has positions, altitude and time, but no totals. Wattspur calculates them from the track and marks the ride **≈ Totals estimated**. Details and limits are in [Importing GPX files](08-importing-gpx.md#what-wattspur-calculates).
| Value | How |
|---|---|
| Ride time ≈ | The time in motion: gaps of 30 s or more are pauses, speed below 0.8 m/s (over ±5 s) is standing still |
| Distance ≈ | Along the track while moving; GPS wobble at a standstill counts nothing |
| Avg speed ≈, Top speed ≈ | Distance ÷ ride time; the fastest stretch of at least 5 s |
| Ascent ≈, Descent ≈ | From the altitude smoothed with a median over 5 points; a climb counts from 3 m |
| Power, cadence | Only if the file has them; otherwise a dash. Work is the sum of the power; without power there is no work |
| Calories | Need power (work); without it a dash |
| CO₂ saved ⓘ | From the distance, as for every ride |

Sums over several rides use the rides that have a value and say how many that is (“9 of 12 rides”). Bosch values replace estimated ones when you update a GPX ride from the Bosch FIT.

## The analysis
| Value | How |
|---|---|
| Totals | Sums over all rides in the period. The sample ride counts only if you select it in the list on purpose |
| Averages (speed, power, cadence) | Weighted by ride time: a two-hour ride counts four times as much as a half-hour ride. That is the same as if all rides were one long ride |
| Avg per ride | Total divided by the number of rides |
| Change (▲ / ▼ %) | Compared with the period before: the previous week, month or year, or a range of the same length before a custom range. “All” has nothing to compare with |
| Trends | The average of each ride as a dot, and the average of the last five rides as a line |

## Comparing rides
| Value | How |
|---|---|
| Calories per km ⓘ, Work per km, Ascent per km | The value divided by the distance in km |
| Coasting share | Share of the ride time without pedal power: 1 − (work ÷ avg power) ÷ ride time. Bosch averages power only over the seconds with pedal power, so work ÷ avg power gives their number. On the sample ride this is 19 %, within one point of counting the seconds |
| Avg power over ride time | Work ÷ ride time: like Bosch's average, but coasting counts as 0 W. Shows how much you pedalled over the whole ride |
| Steepest climb | The steepest gradient over at least 100 m of the ride, from the recorded altitude. Shorter stretches are not counted, because the altitude jumps by a metre or two from second to second |
| Average (difference from average) | Your typical ride: the mean per ride over all rides, without the sample ride and the trash. Averages (speed, power, cadence, power over ride time, coasting share) are weighted by ride time, values per km by distance |

## Highlights
| Value | How |
|---|---|
| Records | From the Bosch totals of each ride. On a tie the earlier ride keeps the record. Average speed and average power count only for rides of 5 km or more, so a short ride downhill sets no record |
| Longest streak | Consecutive calendar days with at least one ride, by the local date where the ride started. Two rides on one day count as one day; a day without a ride ends the streak; a single day is no streak |
| Year | Rides belong to the year and month of their local start date. The change against the year before compares the distance |
| Goals | The sum of the rides that started in the period. Weeks run from Monday to Sunday. “On track” means the goal is at least as far as the share of the period that has passed |
| Not counted | The sample ride, rides in the trash, and the parts of a merged ride (the merged ride counts as one ride) |

## Map
| Value | How |
|---|---|
| Rides on the map | As in the analysis: without the sample ride (unless selected) and the trash; a merged ride is one ride. The route is simplified to within 5 m |
| Tiles below the map | Whole rides whose route touches the visible area, with their Bosch totals; average speed weighted by ride time |
| Heat map | Number of different rides per area of about 16 pt; each ride counts once per area. Fixed steps 1, 2–4, 5–9, 10–19, 20+ |
| New paths | Share of the distance in 50 m fields that none of your earlier rides had passed. Deviations up to 10 m (GPS) count as known; a path 50 m away is new. The kilometres are this share of the Bosch distance. Out and back on a new road counts as new both ways |

## Rounding
Wattspur shows distance to 0.1 km, speed to 0.1 km/h, and power, cadence and metres as whole numbers. Totals in the analysis are calculated from the exact values and rounded only at the end, so they can differ from a sum of the rounded values by 0.1.

---
Next: [FAQ and troubleshooting](06-faq.md)
