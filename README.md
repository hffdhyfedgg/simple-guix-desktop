

Собираю свой образ для установки guix.

Сборка состоит из двух основных частей:
1. Замыкание системы. Файл `for_flight/config/configuration.scm` использовался с `guix time-machine -C for_flight/channels.scm -- system build for_flight/config/configuration.scm`. Далее это замыкание упаковывается в `.nar`: 
```
guix archive --export --recursive /gnu/store/***-system > system-closure.nar
```
После используем `scripts/make-nar-parts.sh`. Части архива оказываются в `for_flight/nars`.
2. Установочный образ. Он должен содержать в себе всё необходимое для установки на борту. Все файлы для целевой системы должны будут импортированы в `/gnu/store` из `nars` и система должна установиться полностью без зависимотей.

Guix в `insaller.scm` настроен так, чтобы он содержал состояние каналов с нужными коммитами: теми же самыми, что использовались при сборке замыкания итоговой системы.

---
```sh
# 1. На машине сборки: экспортируем closure системы в NAR
guix archive --export --recursive \
  /gnu/store/1lnp54v9i2h6wdwyj8laj3m1yw17gdif-system \
  > system-closure.nar

# 2. Включаем NAR в ISO через локальный пакет
# (как показал предыдущий ассистент)

# 3. На целевой машине (из ISO-установщика): импортируем
guix archive --import < /path/to/system-closure.nar
```

Как собрать образ:
```sh
# Тут не указана `guix time-machine`! А она нужна!
# Собираем ISO с включённым замыканием
guix system image --image-type=iso9660 \
  installer.scm
```
