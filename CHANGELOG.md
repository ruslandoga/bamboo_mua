# Changelog

## Unreleased

- add Date and Message-ID headers if missing

## 0.2.1 (2024-06-12)

- skip MX lookups when using relay

## 0.2.0 (2024-05-29)

- update Mua to v0.2.0, which splits `:transport_opts` into `:tcp` and `:ssl` options https://github.com/ruslandoga/mua/pull/44

## 0.1.5 (2024-02-28)

- improve documentation and don't include content-length header for attachments https://github.com/ruslandoga/bamboo_mua/pull/26

## 0.1.4 (2023-12-30)

- relax Bamboo version requirement

## 0.1.3 (2023-12-26)

- update docs

## 0.1.2 (2023-07-15)

- add multihost error and refactor https://github.com/ruslandoga/bamboo_mua/pull/3

## 0.1.1 (2023-07-13)

- prepare recipients before rendering https://github.com/ruslandoga/bamboo_mua/pull/2
