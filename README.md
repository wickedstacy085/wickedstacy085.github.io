# Портфолио Анастасии Смирновой

Исходный код сайта https://wickedstacy085.github.io: проекты по эконометрике временных рядов
и макропрогнозированию. Сайт собирается из этого репозитория в GitHub Actions при каждом коммите.

| Проект | Методы | Язык | README |
|---|---|---|---|
| [Цены на жильё в Германии](projects/housing-vecm/) | ARIMA, VAR, VECM, тест Йохансена, скользящая проверка прогнозов | R | [README](projects/housing-vecm/README.md) |
| [Финансовая эконометрика](projects/financial-econometrics/) | МНК, MLE, модель Фамы–Френча | Python | — |
| [Процесс Орнштейна–Уленбека](projects/ou-process/) | симуляция стохастического процесса | Python | — |

## Структура

```
_quarto.yml                  настройки сайта
index.qmd, projects.qmd      главная и список проектов
cv.qmd                       резюме (HTML и PDF)
projects/<проект>/index.qmd  страница проекта; код в R/, данные в data/
.github/workflows/publish.yml  сборка и публикация в ветку gh-pages
```

## Сборка

Нужны Quarto ≥ 1.4, R ≥ 4.3 и Python ≥ 3.10 с пакетами из `requirements.txt`. Команда:
`quarto render`. Как воспроизвести конкретный проект, написано в его README.

## Лицензия

Код — MIT, тексты — CC BY 4.0.
