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

## Aanbevolen: bewaking

De storing hierboven is **stil**: de add-on blijft draaien, de integratie blijft draaien, en
toch verdwijnen alle entiteiten. De HA-watchdog van de add-on ziet dit niet — die herstart
alleen bij een gecrasht proces, en het proces crasht niet. Het enige betrouwbare signaal is
dat de entiteiten massaal `unavailable` worden.

Deze automation slaat daarop alarm, herstart de add-on, en meldt tien minuten later of dat
hielp. Vervang de `addon`-slug: die is een hash van de repo-URL en verschilt per installatie
(kijk in de URL van de add-on-pagina in HA). Vervang ook
`persistent_notification.create` als je liever een pushmelding krijgt.

```yaml
alias: Eufy - bewaking en automatisch herstel
triggers:
  - trigger: template
    value_template: >
      {% set e = integration_entities('eufy_security') %}{% set n = e | count %}
      {{ n > 0 and (e | select('is_state','unavailable') | list | count) / n > 0.8 }}
    for: "00:15:00"
conditions: []
actions:
  - action: persistent_notification.create
    data:
      notification_id: eufy_watchdog
      title: Eufy-entiteiten weg - add-on wordt herstart
      message: >-
        {% set e = integration_entities('eufy_security') %}
        {{ e | select('is_state','unavailable') | list | count }} van de {{ e | count }}
        Eufy-entiteiten staan al 15 minuten op unavailable.
  - action: hassio.addon_restart
    data:
      addon: xxxxxxxx_eufy_security_ws_fix   # <-- pas dit aan
  - delay: "00:10:00"
  - if:
      - condition: template
        value_template: >
          {% set e = integration_entities('eufy_security') %}{% set n = e | count %}
          {{ n > 0 and (e | select('is_state','unavailable') | list | count) / n > 0.8 }}
    then:
      - action: persistent_notification.create
        data:
          notification_id: eufy_watchdog
          title: Eufy nog steeds stuk na herstart
          message: >-
            Herstart hielp niet. Check de add-on-log op "Response code not ok" of
            "No devices found" — dat wijst op een nieuwe Eufy API-wijziging die een
            code-fix vereist.
    else:
      - action: persistent_notification.create
        data:
          notification_id: eufy_watchdog
          title: Eufy hersteld na herstart
          message: De add-on-herstart heeft het opgelost.
mode: single
```

Een herstart lost alleen de tijdelijke storingen op (verlopen sessie, weggevallen
verbinding). Raakt Eufy de API opnieuw aan, dan helpt geen herstart en is een code-fix
nodig — daarvoor is de tweede melding.
