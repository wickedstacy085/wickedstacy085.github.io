# Анастасия Смирнова · портфолио

Эконометрика временных рядов и макропрогнозирование. Сайт: https://USERNAME.github.io

| Проект | Методы | Стек |
|---|---|---|
| [Цены на жильё: коинтеграция и прогноз](projects/housing-vecm/) | ARIMA, VAR, VECM, Йохансен, IRF, FEVD | R |
| [Финансовая эконометрика](projects/financial-econometrics/) | МНК, MLE, CAPM, Fama–French | Python |
| [Процесс Орнштейна–Уленбека](projects/ou-process/) | стохастические процессы, симуляция | Python |

## Как воспроизвести

```bash
# R-окружение
Rscript -e 'install.packages("renv"); renv::restore()'
# Python-окружение
python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
# Сборка сайта
quarto render
```

Структура: каждый проект лежит в `projects/<slug>/`. Там `index.qmd` с текстом кейса,
`R/` или `notebooks/` с кодом, а также `data/` с данными или инструкцией по их загрузке.
