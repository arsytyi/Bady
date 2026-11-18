/// Enums stored in the database by index: only append new values at the end.
library;

enum MedKind { medicine, supplement }

enum MedForm { tablet, capsule, drops, liquid, powder, injection, spray, other }

enum MealRelation { any, before, during, after, emptyStomach }

enum DoseStatus { taken, skipped, missed, snoozed }
