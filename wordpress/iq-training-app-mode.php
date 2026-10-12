<?php
/**
 * Plugin Name: IQ Training App Mode
 * Description: Adjusts the site when it is opened inside the IQ Training mobile app: hides the header and footer, and keeps course sales out of the app.
 * Version: 1.0.0
 *
 * Install as a single-file plugin (wp-content/plugins/iq-training-app-mode.php)
 * or paste the code below the header into a Code Snippets entry.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * WooCommerce product IDs that may be bought inside the app.
 * Physical goods only: put the printed certificate product ID here.
 * Example: array( 12345 )
 */
function iq_app_allowed_product_ids() {
	return array();
}

/** Where the app sends people instead of sales pages. */
function iq_app_home_url() {
	return is_user_logged_in()
		? home_url( '/user-dashboard/my-courses/' )
		: home_url( '/login/' );
}

/** True when the request comes from the mobile app's webview. */
function iq_is_app() {
	$ua = isset( $_SERVER['HTTP_USER_AGENT'] ) ? (string) $_SERVER['HTTP_USER_AGENT'] : '';
	return false !== stripos( $ua, 'IQTrainingApp' );
}

/** Never serve the app a cached copy of the normal site, or the reverse. */
add_action(
	'init',
	function () {
		if ( iq_is_app() ) {
			do_action( 'litespeed_control_set_nocache', 'IQ Training app request' );
		}
	}
);

add_filter(
	'body_class',
	function ( $classes ) {
		if ( iq_is_app() ) {
			$classes[] = 'iq-app';
		}
		return $classes;
	}
);

add_action(
	'wp_head',
	function () {
		if ( ! iq_is_app() ) {
			return;
		}
		echo '<style id="iq-app-css">'
			. '.iq-app .elementor-location-header,.iq-app .elementor-location-footer,'
			. '.iq-app #masthead,.iq-app .site-footer{display:none!important}'
			. '</style>';
	}
);

/** Send the app away from the catalogue, course sales pages and the home page. */
add_action(
	'template_redirect',
	function () {
		if ( ! iq_is_app() || is_admin() || wp_doing_ajax() ) {
			return;
		}

		$blocked = is_front_page()
			|| is_page( array( 'courses', 'course-bundles', 'teams-training' ) )
			|| is_post_type_archive( 'sfwd-courses' );

		if ( ! $blocked && function_exists( 'is_shop' ) ) {
			$blocked = is_shop() || is_product_category() || is_product_tag();
			if ( ! $blocked && is_product() ) {
				$blocked = ! in_array( (int) get_queried_object_id(), iq_app_allowed_product_ids(), true );
			}
		}

		// "/?add-to-cart=123" style requests hit the front page; let them through.
		if ( $blocked && is_front_page() && ! empty( $_GET ) ) { // phpcs:ignore WordPress.Security.NonceVerification
			$blocked = false;
		}

		if ( $blocked ) {
			wp_safe_redirect( iq_app_home_url() );
			exit;
		}
	},
	5
);

/** Inside the app, only the allowed physical products can be added to the cart. */
add_filter(
	'woocommerce_is_purchasable',
	function ( $purchasable, $product ) {
		if ( ! iq_is_app() ) {
			return $purchasable;
		}
		$allowed = iq_app_allowed_product_ids();
		$id      = (int) $product->get_id();
		$parent  = (int) $product->get_parent_id();
		return $purchasable && ( in_array( $id, $allowed, true ) || in_array( $parent, $allowed, true ) );
	},
	10,
	2
);
