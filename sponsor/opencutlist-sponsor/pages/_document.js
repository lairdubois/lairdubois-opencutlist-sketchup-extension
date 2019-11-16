import Document, { Html, Head, Main, NextScript } from 'next/document'

export default class MyDocument extends Document {

    static async getInitialProps(ctx) {
        const initialProps = await Document.getInitialProps(ctx);
        return {...initialProps}
    }

    render() {
        return (
            <Html>
                <Head>
                    <meta name="viewport" content="initial-scale=1.0, width=device-width" />
                </Head>
                <body>
                <Main/>
                <NextScript/>
                </body>
            </Html>
        )
    }

}