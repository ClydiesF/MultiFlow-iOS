# MultiFlow-iOS

MultiFlow is a professional-grade iOS application designed for multi-family real estate investors to perform rapid, high-fidelity property valuations. Built with a "Clean Canvas" aesthetic, the app simplifies complex commercial real estate math—such as Cap Rates, Debt Coverage Ratios (DCR), and forced appreciation—into an intuitive, mobile-first experience.

🚀 # Key Features
Dynamic Rent Roll Formatter: Aggregates multi-unit income with automated property type badging (Duplex, Triplex, Quadplex, Commercial).

PITI & Financing Calculator: Real-time mortgage breakdown with interactive Swift Charts (Pie Charts) for P&I, Taxes, and Insurance.

Financial Health Grader: An "AI-Advisor" engine that assigns A-F grades to deals based on CoC Return, DCR, and Expense Ratios, providing actionable insights for deal optimization.

Value-Add Simulator: Visualizes "Forced Appreciation" by calculating After Repair Value (ARV) based on projected rent bumps and market Cap Rates.

Portfolio Analytics: A horizontal paging dashboard featuring Equity Growth lines, Cash Flow vs. Appreciation area charts, and Unit Scale step charts.

🛠 ## Tech Stack
Language: Swift 6 / SwiftUI

Frameworks: Swift Charts (Data Viz), Combine (Reactive Logic)

Database & Backend: Supabase (Auth, Postgres, Realtime, Storage)

Architecture: MVVM (Model-View-ViewModel) with a dedicated MetricEngine for financial logic.

UI/UX: Custom "Clean Canvas" design system utilizing a high-contrast Yellow, Black, and Grey palette.

📂 ## Repository Structure
/Models: Codable entities for properties, units, and portfolio analytics.

/Views: Reusable SwiftUI components (MetricCards, FloatingTabBar, PropertyBadges).

/Engines: The "MultiFlow" core logic for DCR, Cap Rate, and Financial Grading.

/Resources: Design assets, Color extensions, and Theme configurations.
