import katex from 'katex';

// The Markdown preview and visual node views use the same pinned renderer.
// Retain the existing preview API (including its missing-resource fallback).
(window as Window & {katex: typeof katex}).katex=katex;
