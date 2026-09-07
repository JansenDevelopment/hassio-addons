# JansenDevelopment Home Assistant Add-ons

Eigen Home Assistant add-on repository.

## Toevoegen aan Home Assistant

Instellingen → Add-ons → Add-on Store → ⋮ → Repositories, en dan:

```
https://github.com/JansenDevelopment/hassio-addons
```

## Add-ons

### eufy-security-ws (Mega fixes)

`eufy-security-ws` 3.1.0 met een gepatchte `eufy-security-client`
([fork](https://github.com/JansenDevelopment/eufy-security-client/tree/mega-fixes),
`mega-fixes`). Los van de originele add-on van bropat te installeren; ze kunnen niet
tegelijk draaien, want beide gebruiken `host_network` op poort 3000.

Waarom deze fork bestaat — twee storingen door Eufy's migratie naar de Mega/v6-backend:

1. **Geen devices meer.** `v2/passport/profile` geeft nu `code: 200` in plaats van
   `code: 0`. De client accepteert alleen `0`, dus de profile-call faalt, `connected`
   blijft `false` en `makePostRequest()` slaat álle house/station/device-requests stil
   over. Resultaat: "No houses/stations/devices found" en alle entiteiten `unavailable`.
2. **Geen push-events meer.** `register_push_token` op de Mega-backend antwoordt met
   `code: 4404` (`CODE_NEED_NEGOTIATE_KEY`, "get identity error"). De client gooit de
   verlopen identity weg maar retryt niet, dus push valt weg. Omdat de identity uit de
   persisted session terugkomt, hielp herstarten niet.

Beide fixes komen van
[ivivona/eufy-security-client](https://github.com/ivivona/eufy-security-client)
(upstream [PR #975](https://github.com/bropat/eufy-security-client/pull/975) en de
retry-commit bij [issue #586](https://github.com/bropat/eufy-security-ws/issues/586)).
Upstream is [einde ontwikkeling](https://github.com/bropat/eufy-security-client/issues/965)
sinds 2026-07-20, dus die PR's worden niet meer gemerged.

> **Let op:** Eufy zet de legacy-API's stap voor stap uit. Dit is een verlengstuk met
> beperkte levensduur, geen structurele oplossing.
