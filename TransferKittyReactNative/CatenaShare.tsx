import React from 'react';
import { SafeAreaView, Animated, StyleSheet, Text, View, Button, TabBarIOS } from 'react-native';

import ShareHeader from './components/share-header';
import DeviceList from './components/device-list';

export default function CatenaShare() {
  return (
    // <SafeAreaView>
      <View style={styles.container}>
        <View style={styles.contentWrapper}>
          <ShareHeader />
          <DeviceList />
        </View>
      </View>
    // </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'stretch',
  },
  contentWrapper: {
    flex: 1,
    backgroundColor: '#fff',
    opacity: 0.95,
  }
});
