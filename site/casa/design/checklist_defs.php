<?php
// Shared checklist definition - order and labels for the per-room progress tracker. Each category
// is a card that can hold any number of items (see casa_design_checklist_items); every item gets
// the same pair of steps (Cumpărat / Montat) plus its own estimated/real cost.
// index.php (render) and checklist_item_*.php (validate the category) all include this so the set
// of cards can't drift apart between them.
$casaChecklistDefs = [
    'var' => [
        'label' => 'Var & Tapet',
    ],
    'parchet' => [
        'label' => 'Gresie/parchet',
    ],
    'mobila' => [
        'label' => 'Mobilă',
    ],
    'iluminat' => [
        'label' => 'Electrice',
    ],
    'tapet' => [
        'label' => 'Accesorii',
    ],
    'decor' => [
        'label' => 'Decor',
    ],
];
