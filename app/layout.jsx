import "./globals.css";

export const metadata = {
    title: "Radical Resolve",
    description: "De-escalate your reality.",
};

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <body>{children}</body>
        </html>
    );
}
